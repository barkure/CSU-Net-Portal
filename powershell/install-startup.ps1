$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $HOME "csu-autoauth.ps1"
$startupDir = [Environment]::GetFolderPath("Startup")
$launcherPath = Join-Path $startupDir "csu-autoauth.cmd"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$launcherContent = @"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$scriptPath"
"@

Set-Content -Path $launcherPath -Value $launcherContent -Encoding ASCII
Write-Output "Startup launcher created: $launcherPath"

$runningProcesses = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^powershell(\.exe)?$' -and $_.CommandLine -like "*$scriptPath*"
}

if (-not $runningProcesses) {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $scriptPath
    )
    Write-Output "Script started in background: $scriptPath"
} else {
    Write-Output "Script is already running: $scriptPath"
}
