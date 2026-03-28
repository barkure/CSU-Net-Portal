$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $HOME "csu-autoauth.ps1"
$configDir = Join-Path $HOME ".config\csu-autoauth"
$configPath = Join-Path $configDir "config.ps1"
$startupDir = [Environment]::GetFolderPath("Startup")
$launcherPath = Join-Path $startupDir "csu-autoauth.cmd"
$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceScript = Join-Path $sourceDir "csu-autoauth.ps1"
$sourceConfig = Join-Path $sourceDir "config.ps1.example"

if (-not (Test-Path -LiteralPath $sourceScript)) {
    throw "Script not found: $sourceScript"
}

if (-not (Test-Path -LiteralPath $sourceConfig)) {
    throw "Config template not found: $sourceConfig"
}

New-Item -ItemType Directory -Path $configDir -Force | Out-Null
Copy-Item -LiteralPath $sourceScript -Destination $scriptPath -Force

if (-not (Test-Path -LiteralPath $configPath)) {
    Copy-Item -LiteralPath $sourceConfig -Destination $configPath
}

$launcherContent = @"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$scriptPath"
"@

Set-Content -Path $launcherPath -Value $launcherContent -Encoding ASCII
Write-Output "Startup launcher created: $launcherPath"
Write-Output "Installed script: $scriptPath"
Write-Output "Installed config: $configPath"

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
