$ErrorActionPreference = "Stop"

$RepoRawUrl = if ($env:REPO_RAW_URL) { $env:REPO_RAW_URL } else { "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main" }
$InstallerUrl = "$RepoRawUrl/powershell/common/install-main.ps1"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$webClient = New-Object System.Net.WebClient

try {
    $scriptBytes = $webClient.DownloadData($InstallerUrl)
} finally {
    $webClient.Dispose()
}

$installerScript = [System.Text.Encoding]::UTF8.GetString($scriptBytes)
[ScriptBlock]::Create($installerScript).Invoke()
