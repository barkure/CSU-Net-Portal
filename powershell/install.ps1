$ErrorActionPreference = "Stop"

$RepoRawUrl = if ($env:REPO_RAW_URL) { $env:REPO_RAW_URL } else { "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main" }
$InstallerUrl = "$RepoRawUrl/powershell/common/install-main.ps1"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$webClient = New-Object System.Net.WebClient
$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("csu-autoauth-install-{0}.ps1" -f ([System.Guid]::NewGuid().ToString("N")))

try {
    $scriptBytes = $webClient.DownloadData($InstallerUrl)
    $installerScript = [System.Text.Encoding]::UTF8.GetString($scriptBytes)
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($tempPath, $installerScript, $utf8Bom)
} finally {
    $webClient.Dispose()
}

try {
    & $tempPath
} finally {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }
}
