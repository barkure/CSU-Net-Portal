$ErrorActionPreference = "Stop"

$InstallerUrl = "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/common/install-main.ps1"

# Windows 服务安装需要管理员，提前检查权限。
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "安装 Windows 服务需要管理员权限。请以管理员身份重开 PowerShell 后重试。"
}

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
