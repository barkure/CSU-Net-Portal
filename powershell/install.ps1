$ErrorActionPreference = "Stop"

$InstallerUrl = "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/common/install-main.ps1"

# Check administrator privileges before installing the Windows service.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "Administrator privileges are required. Reopen PowerShell as administrator and retry."
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$webClient = New-Object System.Net.WebClient
$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("csu-autoauth-install-{0}.ps1" -f ([System.Guid]::NewGuid().ToString("N")))

try {
    $scriptBytes = $webClient.DownloadData($InstallerUrl)
    # Normalize UTF-8 input to exactly one BOM for Windows PowerShell 5.1.
    $scriptText = [System.Text.Encoding]::UTF8.GetString($scriptBytes).TrimStart([char]0xFEFF)
    [System.IO.File]::WriteAllText($tempPath, $scriptText, (New-Object System.Text.UTF8Encoding($true)))
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
