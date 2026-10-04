$ErrorActionPreference = "Stop"

$HomeDir = $HOME
$BinDir = Join-Path $HomeDir ".local\bin"
$StartupDir = [Environment]::GetFolderPath("Startup")
$LauncherPath = Join-Path $StartupDir "csu-autoauth.vbs"
$ScriptPath = Join-Path $BinDir "csu-autoauth.ps1"
$ConfigDir = Join-Path $HomeDir ".config\csu-autoauth"
$DataDir = Join-Path $HomeDir ".local\share\csu-autoauth"

$ServiceName = if ($env:CSU_SERVICE_NAME) { $env:CSU_SERVICE_NAME } else { "csu-autoauth" }
$ServiceExeName = "$ServiceName-service.exe"
$ServiceExe = Join-Path $BinDir $ServiceExeName
$ServiceXml = Join-Path $BinDir "$ServiceName-service.xml"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# WinSW 会把进度写到 stderr；PS 5.1 下 $ErrorActionPreference=Stop 会把 stderr 当终止错误。
function Invoke-ServiceExe {
    param([string]$Command)

    if (-not (Test-Path -LiteralPath $ServiceExe)) {
        return
    }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $ServiceExe $Command 2>&1 | ForEach-Object { Write-Output "  $([string]$_)" }
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Remove-Service {
    $service = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
    if (-not $service) {
        return
    }

    if (-not (Test-Administrator)) {
        throw "卸载 Windows 服务需要管理员权限。请以管理员身份重开 PowerShell 后重试。"
    }

    if ($service.PathName -and $service.PathName -notlike "*$ServiceExe*") {
        throw "Refusing to remove service registered outside this installation: $($service.PathName)"
    }

    if (Test-Path -LiteralPath $ServiceExe) {
        Invoke-ServiceExe -Command "stop"
        Invoke-ServiceExe -Command "uninstall"

        # 服务卸载后 WinSW 进程可能还在持有 exe，兜底清一次
        Get-CimInstance Win32_Process | Where-Object { $_.Name -eq $ServiceExeName } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }

    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Output "Service $ServiceName is still registered at '$($service.PathName)'; removing via sc.exe"
        # 安全网：只删指向本安装目录的注册项，避免误删同名但指向别处的服务
        if ($service.PathName -and $service.PathName -notlike "*$BinDir*") {
            throw "Refusing to delete service registered outside $BinDir."
        }

        & sc.exe delete $ServiceName 2>&1 | ForEach-Object { Write-Output "  $([string]$_)" }
        if ($LASTEXITCODE -ne 0) { throw "Service removal failed; installation files have been preserved." }
    }

    Write-Output "Removed service: $ServiceName"
}

Remove-Service

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

foreach ($serviceFile in @($ServiceXml, $ServiceExe, "$ServiceExe.download")) {
    if (Test-Path -LiteralPath $serviceFile) {
        Remove-Item -LiteralPath $serviceFile -Force
        Write-Output "Removed service file: $serviceFile"
    }
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
