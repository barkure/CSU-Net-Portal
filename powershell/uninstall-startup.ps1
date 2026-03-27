$ErrorActionPreference = "Stop"

$startupDir = [Environment]::GetFolderPath("Startup")
$launcherPath = Join-Path $startupDir "csu-autoauth.cmd"
$scriptPath = Join-Path $HOME "csu-autoauth.ps1"

if (Test-Path -LiteralPath $launcherPath) {
    Remove-Item -LiteralPath $launcherPath -Force
    Write-Output "Startup launcher removed: $launcherPath"
} else {
    Write-Output "Startup launcher not found: $launcherPath"
}

$runningProcesses = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^powershell(\.exe)?$' -and $_.CommandLine -like "*$scriptPath*"
}

foreach ($process in $runningProcesses) {
    Stop-Process -Id $process.ProcessId -Force
    Write-Output "Stopped process: $($process.ProcessId)"
}
