$ErrorActionPreference = "Stop"

$UninstallerUrl = if ($env:CSU_BASE_URL) { "$($env:CSU_BASE_URL.TrimEnd('/'))/pwsh/common/uninstall-main.ps1" } else { "https://ssuu.us/csunet/pwsh/common/uninstall-main.ps1" }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "Administrator privileges are required. Reopen PowerShell as administrator and retry."
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$webClient = New-Object System.Net.WebClient
$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("csu-net-auth-uninstall-{0}.ps1" -f ([System.Guid]::NewGuid().ToString("N")))

try {
    $scriptBytes = $webClient.DownloadData($UninstallerUrl)
    # Write UTF-8 with BOM for Windows PowerShell 5.1.
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
