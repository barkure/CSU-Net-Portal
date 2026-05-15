namespace CSUNetKeeper.Models;

public sealed class AppConfig
{
    public string Username { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public string Type { get; set; } = "1";

    public int IntervalSeconds { get; set; } = 10;

    public bool AutoAuthEnabled { get; set; }
}
