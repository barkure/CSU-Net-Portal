using CSUNetKeeper.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace CSUNetKeeper.Services;

public sealed class PortalClient : IDisposable
{
    private static readonly IReadOnlyDictionary<string, string> NetSuffixMap = new Dictionary<string, string>
    {
        ["1"] = "cmccn",
        ["2"] = "unicomn",
        ["3"] = "telecomn",
        ["4"] = string.Empty
    };

    private readonly HttpClient _httpClient;

    public PortalClient()
    {
        var handler = new HttpClientHandler
        {
            UseProxy = false,
            ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
        };

        _httpClient = new HttpClient(handler)
        {
            Timeout = TimeSpan.FromSeconds(5)
        };
    }

    public string BuildUserAccount(AppConfig config)
    {
        var suffix = NetSuffixMap.TryGetValue(config.Type, out var value) ? value : string.Empty;
        return string.IsNullOrWhiteSpace(suffix) ? config.Username : $"{config.Username}@{suffix}";
    }

    public async Task<bool> TestOnlineAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "http://captive.apple.com");
            using var response = await _httpClient.SendAsync(request, cancellationToken);
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            return body.Contains("Success", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    public async Task<string> LoginAsync(AppConfig config, CancellationToken cancellationToken)
    {
        var userAccount = BuildUserAccount(config);
        var query = new Dictionary<string, string>
        {
            ["user_account"] = userAccount,
            ["user_password"] = config.Password
        };

        var url = QueryHelpers.AddQueryString("https://10.1.1.1:802/eportal/portal/login", query);
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        using var response = await _httpClient.SendAsync(request, cancellationToken);
        return await response.Content.ReadAsStringAsync(cancellationToken);
    }

    public async Task<string> UnbindMacAsync(AppConfig config, CancellationToken cancellationToken)
    {
        var query = new Dictionary<string, string>
        {
            ["user_account"] = config.Username
        };

        var url = QueryHelpers.AddQueryString("https://10.1.1.1:802/eportal/portal/mac/unbind", query);
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        using var response = await _httpClient.SendAsync(request, cancellationToken);
        return await response.Content.ReadAsStringAsync(cancellationToken);
    }

    public async Task<string> LogoutAsync(CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "https://10.1.1.1:802/eportal/portal/logout");
        using var response = await _httpClient.SendAsync(request, cancellationToken);
        return await response.Content.ReadAsStringAsync(cancellationToken);
    }

    public LoginEvaluation EvaluateLoginResponse(string response)
    {
        if (string.IsNullOrWhiteSpace(response))
        {
            return new LoginEvaluation(false, false, LoginFailureKind.Unknown, "认证失败：服务器没有返回有效内容。");
        }

        var payload = ExtractJsonPayload(response);

        try
        {
            using var document = JsonDocument.Parse(payload);
            var root = document.RootElement;

            if (TryGetString(root, "result", out var result))
            {
                if (string.Equals(result, "success", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(result, "1", StringComparison.OrdinalIgnoreCase))
                {
                    return new LoginEvaluation(true, true, LoginFailureKind.None, "认证成功。");
                }

                if (TryGetString(root, "msg", out var msg) && !string.IsNullOrWhiteSpace(msg))
                {
                    if (IsAlreadyAuthenticatedResponse(msg))
                    {
                        return new LoginEvaluation(false, true, LoginFailureKind.AlreadyAuthenticated, "当前网络已认证，无需重复登录。");
                    }

                    if (IsPasswordError(msg))
                    {
                        return new LoginEvaluation(false, false, LoginFailureKind.InvalidCredentials, "账号或密码错误。");
                    }

                    if (IsOperatorError(msg))
                    {
                        return new LoginEvaluation(false, false, LoginFailureKind.InvalidOperator, "运营商选择不正确。");
                    }

                    return new LoginEvaluation(false, false, LoginFailureKind.Unknown, $"认证失败：{NormalizeMessage(msg)}");
                }

                if (TryGetString(root, "message", out var message) && !string.IsNullOrWhiteSpace(message))
                {
                    return new LoginEvaluation(false, false, LoginFailureKind.Unknown, $"认证失败：{NormalizeMessage(message)}");
                }

                return new LoginEvaluation(false, false, LoginFailureKind.Unknown, $"认证失败：{result}");
            }

            if (TryGetString(root, "ret_code", out var retCode))
            {
                if (TryGetString(root, "msg", out var msg) && !string.IsNullOrWhiteSpace(msg))
                {
                    if (IsAlreadyAuthenticatedResponse(msg))
                    {
                        return new LoginEvaluation(false, true, LoginFailureKind.AlreadyAuthenticated, "当前网络已认证，无需重复登录。");
                    }

                    if (IsPasswordError(msg))
                    {
                        return new LoginEvaluation(false, false, LoginFailureKind.InvalidCredentials, "账号或密码错误。");
                    }

                    if (IsOperatorError(msg))
                    {
                        return new LoginEvaluation(false, false, LoginFailureKind.InvalidOperator, "运营商选择不正确。");
                    }

                    if (retCode is "0" or "1")
                    {
                        return new LoginEvaluation(true, true, LoginFailureKind.None, "认证成功。");
                    }

                    return new LoginEvaluation(false, false, LoginFailureKind.Unknown, $"认证失败：{NormalizeMessage(msg)}");
                }

                return new LoginEvaluation(false, false, LoginFailureKind.Unknown, $"认证失败：{retCode}");
            }
        }
        catch (JsonException)
        {
        }

        var normalized = payload.Trim();
        if (normalized.Contains("success", StringComparison.OrdinalIgnoreCase) &&
            !normalized.Contains("fail", StringComparison.OrdinalIgnoreCase) &&
            !normalized.Contains("error", StringComparison.OrdinalIgnoreCase))
        {
            return new LoginEvaluation(true, true, LoginFailureKind.None, "认证成功。");
        }

        if (IsAlreadyAuthenticatedResponse(normalized))
        {
            return new LoginEvaluation(false, true, LoginFailureKind.AlreadyAuthenticated, "当前网络已认证，无需重复登录。");
        }

        if (IsPasswordError(normalized))
        {
            return new LoginEvaluation(false, false, LoginFailureKind.InvalidCredentials, "账号或密码错误。");
        }

        if (IsOperatorError(normalized))
        {
            return new LoginEvaluation(false, false, LoginFailureKind.InvalidOperator, "运营商选择不正确。");
        }

        return new LoginEvaluation(false, false, LoginFailureKind.Unknown, $"认证失败：{NormalizeMessage(normalized)}。");
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }

    private static bool TryGetString(JsonElement element, string propertyName, out string value)
    {
        if (element.TryGetProperty(propertyName, out var property))
        {
            value = property.ValueKind switch
            {
                JsonValueKind.String => property.GetString() ?? string.Empty,
                JsonValueKind.Number => property.GetRawText(),
                JsonValueKind.True => bool.TrueString,
                JsonValueKind.False => bool.FalseString,
                _ => property.GetRawText()
            };
            return true;
        }

        value = string.Empty;
        return false;
    }

    private static string ExtractJsonPayload(string response)
    {
        var trimmed = response.Trim().TrimEnd(';');
        const string prefix = "jsonpReturn(";
        if (trimmed.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) && trimmed.EndsWith(")"))
        {
            return trimmed.Substring(prefix.Length, trimmed.Length - prefix.Length - 1);
        }

        return trimmed;
    }

    private static bool IsAlreadyAuthenticatedResponse(string message)
    {
        return message.Contains("服务器登录失败", StringComparison.OrdinalIgnoreCase) ||
               message.Contains("错误代码99", StringComparison.OrdinalIgnoreCase) ||
               message.Contains("校园客服", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsPasswordError(string message)
    {
        return message.Contains("ldap auth error", StringComparison.OrdinalIgnoreCase) ||
               message.Contains("请输入正确的校园网门户帐号+密码登陆", StringComparison.OrdinalIgnoreCase) ||
               message.Contains("帐号或密码错误", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsOperatorError(string message)
    {
        return message.Contains("AC认证失败", StringComparison.OrdinalIgnoreCase);
    }

    private static string NormalizeMessage(string message)
    {
        return message
            .Replace("<br/>", " ", StringComparison.OrdinalIgnoreCase)
            .Replace("<br />", " ", StringComparison.OrdinalIgnoreCase)
            .Replace("<br\\/>", " ", StringComparison.OrdinalIgnoreCase)
            .Trim();
    }

    private static class QueryHelpers
    {
        public static string AddQueryString(string uri, IEnumerable<KeyValuePair<string, string>> queryString)
        {
            var pairs = queryString
                .Select(pair => $"{WebUtility.UrlEncode(pair.Key)}={WebUtility.UrlEncode(pair.Value)}");
            return $"{uri}?{string.Join("&", pairs)}";
        }
    }
}

public enum LoginFailureKind
{
    None,
    InvalidCredentials,
    InvalidOperator,
    AlreadyAuthenticated,
    Unknown
}

public sealed record LoginEvaluation(
    bool IsSuccess,
    bool CanProceed,
    LoginFailureKind FailureKind,
    string Message);
