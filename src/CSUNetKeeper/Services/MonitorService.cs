using CSUNetKeeper.Models;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace CSUNetKeeper.Services;

public sealed class MonitorService
{
    private readonly PortalClient _portalClient;

    public MonitorService(PortalClient portalClient)
    {
        _portalClient = portalClient;
    }

    public async Task RunAsync(
        AppConfig config,
        Action<string> log,
        CancellationToken cancellationToken)
    {
        var lastStatus = string.Empty;

        while (!cancellationToken.IsCancellationRequested)
        {
            var isOnline = await _portalClient.TestOnlineAsync(cancellationToken);

            if (isOnline)
            {
                if (lastStatus != "up")
                {
                    lastStatus = "up";
                }
            }
            else
            {
                if (lastStatus != "down")
                {
                    lastStatus = "down";
                    log("Network down.");
                }

                try
                {
                    log($"Authenticating as: {_portalClient.BuildUserAccount(config)}.");
                    var response = await _portalClient.LoginAsync(config, cancellationToken);
                    log($"Login response: {response}");
                    var evaluation = _portalClient.EvaluateLoginResponse(response);
                    if (evaluation.FailureKind is LoginFailureKind.InvalidCredentials or LoginFailureKind.InvalidOperator)
                    {
                        throw new MonitorAuthenticationException(evaluation);
                    }
                }
                catch (MonitorAuthenticationException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    log($"Authentication attempt failed and will retry: {ex.Message}");
                }
            }

            await Task.Delay(TimeSpan.FromSeconds(config.IntervalSeconds), cancellationToken);
        }
    }
}

public sealed class MonitorAuthenticationException : Exception
{
    public MonitorAuthenticationException(LoginEvaluation evaluation)
        : base(evaluation.Message)
    {
        Evaluation = evaluation;
    }

    public LoginEvaluation Evaluation { get; }
}
