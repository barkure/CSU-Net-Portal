using CSUNetKeeper.Models;
using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Windows.Storage;

namespace CSUNetKeeper.Services;

public sealed class ConfigService
{
    private readonly string _configDirectory;
    private readonly string _configPath;

    public ConfigService()
    {
        _configDirectory = Path.Combine(ApplicationData.Current.LocalCacheFolder.Path, "CSUNetKeeper");
        _configPath = Path.Combine(_configDirectory, "config.json");
        Directory.CreateDirectory(_configDirectory);
    }

    public string ConfigPath => _configPath;

    public async Task<AppConfig> LoadAsync()
    {
        if (!File.Exists(_configPath))
        {
            return new AppConfig();
        }

        await using var stream = File.OpenRead(_configPath);
        var config = await JsonSerializer.DeserializeAsync(
            stream,
            AppConfigJsonContext.Default.AppConfig);
        return config ?? new AppConfig();
    }

    public async Task SaveAsync(AppConfig config)
    {
        Directory.CreateDirectory(_configDirectory);

        await using var stream = File.Create(_configPath);
        await JsonSerializer.SerializeAsync(
            stream,
            config,
            AppConfigJsonContext.Default.AppConfig);
    }
}
