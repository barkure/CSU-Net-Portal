using System;
using System.IO;
using Windows.Storage;

namespace CSUNetKeeper.Services;

public sealed class LogService
{
    private readonly string _logDirectory;
    private const int RetentionDays = 7;

    public LogService()
    {
        _logDirectory = Path.Combine(ApplicationData.Current.LocalCacheFolder.Path, "CSUNetKeeper");
        Directory.CreateDirectory(_logDirectory);
    }

    public string LogDirectory => _logDirectory;

    public void AppendLine(string line)
    {
        Directory.CreateDirectory(_logDirectory);
        DeleteExpiredLogs();

        var logPath = GetLogPathForDate(DateTime.Now);
        File.AppendAllText(logPath, line + Environment.NewLine);
    }

    public void Clear()
    {
        Directory.CreateDirectory(_logDirectory);
        foreach (var file in Directory.GetFiles(_logDirectory, "*.log"))
        {
            File.Delete(file);
        }
    }

    private void DeleteExpiredLogs()
    {
        var cutoffDate = DateTime.Today.AddDays(-(RetentionDays - 1));

        foreach (var file in Directory.GetFiles(_logDirectory, "*.log"))
        {
            var fileName = Path.GetFileNameWithoutExtension(file);
            if (!DateTime.TryParseExact(
                    fileName,
                    "yyyy-MM-dd",
                    null,
                    System.Globalization.DateTimeStyles.None,
                    out var fileDate))
            {
                continue;
            }

            if (fileDate < cutoffDate)
            {
                File.Delete(file);
            }
        }
    }

    private string GetLogPathForDate(DateTime date)
    {
        return Path.Combine(_logDirectory, $"{date:yyyy-MM-dd}.log");
    }
}
