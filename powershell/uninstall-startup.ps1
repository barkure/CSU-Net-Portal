$ErrorActionPreference = "Stop"

$startupDir = [Environment]::GetFolderPath("Startup")
$launcherPath = Join-Path $startupDir "csu-autoauth.cmd"

if (Test-Path -LiteralPath $launcherPath) {
    Remove-Item -LiteralPath $launcherPath -Force
    Write-Output "Startup launcher removed: $launcherPath"
} else {
    Write-Output "Startup launcher not found: $launcherPath"
}
