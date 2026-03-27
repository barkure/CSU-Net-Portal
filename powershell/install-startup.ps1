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
