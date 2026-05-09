$ErrorActionPreference = "Stop"

$HomeDir = $HOME
$StartupDir = [Environment]::GetFolderPath("Startup")
$LauncherPath = Join-Path $StartupDir "csu-autoauth.vbs"
$ScriptPath = Join-Path $HomeDir ".local\bin\csu-autoauth.ps1"
$ConfigDir = Join-Path $HomeDir ".config\csu-autoauth"
$DataDir = Join-Path $HomeDir ".local\share\csu-autoauth"

$runningProcesses = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^powershell(\.exe)?$' -and $_.CommandLine -like "*$ScriptPath*"
}

foreach ($process in $runningProcesses) {
    Stop-Process -Id $process.ProcessId -Force
    Write-Output "Stopped process: $($process.ProcessId)"
}

if (Test-Path -LiteralPath $LauncherPath) {
    Remove-Item -LiteralPath $LauncherPath -Force
    Write-Output "Removed startup launcher: $LauncherPath"
}

if (Test-Path -LiteralPath $ScriptPath) {
    Remove-Item -LiteralPath $ScriptPath -Force
    Write-Output "Removed script: $ScriptPath"
}

if (Test-Path -LiteralPath $ConfigDir) {
    Remove-Item -LiteralPath $ConfigDir -Recurse -Force
    Write-Output "Removed config dir: $ConfigDir"
}

if (Test-Path -LiteralPath $DataDir) {
    Remove-Item -LiteralPath $DataDir -Recurse -Force
    Write-Output "Removed data dir: $DataDir"
}
