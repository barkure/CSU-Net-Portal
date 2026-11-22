#Requires -Version 5.1
#Requires -RunAsAdministrator
# 手动 e2e（勿进 CI）：装临时 *-svctest 服务 → 杀进程看 WinSW 拉起 → 卸载清理。
# 用法：pwsh -NoProfile -File pwsh/test/e2e-service.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSScriptRoot
$InstallMainPath = Join-Path $ScriptDir "common/install-main.ps1"
$RuntimeScript = Join-Path $ScriptDir "common/csu-net-auth.ps1"

$RequestedServiceName = if ($env:CSU_E2E_SERVICE_NAME) { $env:CSU_E2E_SERVICE_NAME } else { "csu-net-auth-svctest" }
if (-not $RequestedServiceName.EndsWith("-svctest") -and -not $env:CSU_E2E_ALLOW_ANY_NAME) {
    throw "Refusing to run: service name '$RequestedServiceName' is not a *-svctest name. Set CSU_E2E_ALLOW_ANY_NAME=1 to override."
}

$Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("csu-net-auth-e2e-" + [Guid]::NewGuid().ToString("N"))
$Failures = @()

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message" -ForegroundColor Cyan
}

function Assert-True {
    param([string]$Label, [bool]$Condition, [string]$Actual = "")

    if ($Condition) {
        Write-Host "PASS: $Label"
    } else {
        Write-Host "FAIL: $Label ($Actual)" -ForegroundColor Red
        $script:Failures += $Label
    }
}

function Get-RegisteredServicePath {
    param([string]$Name)

    $service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $service) { return $null }
    return $service.PathName
}

# 注册路径须在沙箱内，否则拒操作。
function Test-ServiceIsOurs {
    param([string]$Name, [string]$Sandbox)

    $path = Get-RegisteredServicePath -Name $Name
    if (-not $path) { return $true }
    return ($path -like "*$Sandbox*")
}

function Get-ServiceChildProcesses {
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^powershell(\.exe)?$' -and $_.CommandLine -like "*$ScriptPath*"
    }
}

Write-Host "e2e service name : $RequestedServiceName"
Write-Host "sandbox          : $Sandbox"

New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null

# 须在 dot-source 前设置，否则会落成默认服务名。
$env:CSU_TESTING = "1"
$env:CSU_SERVICE_NAME = $RequestedServiceName
. $InstallMainPath

if ($ServiceName -ne $RequestedServiceName) {
    throw "install-main.ps1 resolved service name '$ServiceName' != requested '$RequestedServiceName'"
}
if (-not $ServiceName.EndsWith("-svctest") -and -not $env:CSU_E2E_ALLOW_ANY_NAME) {
    throw "Refusing to run after dot-source: resolved service name '$ServiceName' is not a *-svctest name."
}

$BinDir = Join-Path $Sandbox "bin"
$ConfigDir = Join-Path $Sandbox "config"
$DataDir = Join-Path $Sandbox "data"
$ScriptPath = Join-Path $BinDir "csu-net-auth.ps1"
$ConfigPath = Join-Path $ConfigDir "config.ps1"
$LogFile = Join-Path $DataDir "csu-net-auth.log"
$ServiceExe = Join-Path $BinDir "$ServiceName.exe"
$ServiceXml = Join-Path $BinDir "$ServiceName.xml"
$env:CONFIG_FILE = $ConfigPath

if (-not $ServiceExe.StartsWith($Sandbox)) {
    throw "Refusing to run: ServiceExe '$ServiceExe' is outside sandbox '$Sandbox'"
}

$USERNAME = "e2e-user"
$PASSWORD = "e2e-pass"
$TYPE = "1"

try {
    Write-Step "pre-flight: existing service with this name?"
    $existing = Get-RegisteredServicePath -Name $ServiceName
    if ($existing -and -not ($existing -like "*$Sandbox*")) {
        throw "Refusing to touch service '$ServiceName': it is registered at '$existing' (not our sandbox)."
    }
    Write-Host "  no conflicting registration"

    # 服务跑 PS 5.1；单独门禁 BOM/解析。
    Write-Step "Windows PowerShell 5.1 parse gate"
    $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $parseHarness = Join-Path $Sandbox 'parse-count.ps1'
    $parseHarnessBody = @'
param([string]$Path)
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
Write-Output $errors.Count
'@
    [System.IO.File]::WriteAllText($parseHarness, $parseHarnessBody, (New-Object System.Text.UTF8Encoding($true)))

    foreach ($file in Get-ChildItem -Path $ScriptDir -Filter *.ps1 -Recurse) {
        $count = [int]((& $ps51 -NoProfile -ExecutionPolicy Bypass -File $parseHarness -Path $file.FullName | Select-Object -Last 1))
        Assert-True "5.1 parse $($file.Name)" ($count -eq 0) "errors=$count"
    }

    Write-Step "Install-CommonFiles + Install-Service"
    Install-CommonFiles
    Copy-Item -LiteralPath $RuntimeScript -Destination $ScriptPath -Force

    Install-Service

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    Assert-True "service registered" ($null -ne $service)

    $running = $false
    for ($i = 0; $i -lt 12; $i++) {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq "Running") { $running = $true; break }
        Start-Sleep -Seconds 2
    }
    Assert-True "service RUNNING" $running "status=$($service.Status)"
    Assert-True "service start type Automatic" ($service.StartType -eq "Automatic") "startType=$($service.StartType)"
    Assert-True "winsw xml written" (Test-Path -LiteralPath $ServiceXml)
    Assert-True "winsw exe verified" ((Get-FileHash -LiteralPath $ServiceExe -Algorithm SHA256).Hash -eq $WinSwAssets["AMD64"].Sha256)

    $children = Get-ServiceChildProcesses
    Assert-True "powershell child is running the sandbox script" ($children.Count -ge 1) "children=$($children.Count)"
    $firstPid = if ($children.Count -ge 1) { $children[0].ProcessId } else { 0 }

    Write-Step "service log content"
    Start-Sleep -Seconds 3
    $logText = if (Test-Path -LiteralPath $LogFile) { [string]((Get-Content -LiteralPath $LogFile -Raw) -join "`n") } else { "" }
    if ($logText) {
        $logText.Trim().Split("`n") | Select-Object -Last 4 | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "  (empty)"
        $winswLogDir = Join-Path $DataDir "logs"
        if (Test-Path -LiteralPath $winswLogDir) {
            Get-ChildItem -LiteralPath $winswLogDir | ForEach-Object {
                Write-Host "  -- $($_.Name) --"
                Get-Content -LiteralPath $_.FullName -Tail 10 | ForEach-Object { Write-Host "     $_" }
            }
        }
    }
    Assert-True "log contains startup banner" ($logText.Contains("Start monitoring"))

    Write-Step "kill child process $firstPid and wait for WinSW onfailure restart"
    if ($firstPid -gt 0) {
        Stop-Process -Id $firstPid -Force
    }

    $restarted = $false
    for ($i = 0; $i -lt 24; $i++) {
        Start-Sleep -Seconds 5
        $children = Get-ServiceChildProcesses
        if ($children.Count -ge 1 -and $children[0].ProcessId -ne $firstPid) {
            $restarted = $true
            Write-Host "  restarted as PID $($children[0].ProcessId) after $(($i + 1) * 5)s"
            break
        }
    }
    Assert-True "service auto-restarted after crash" $restarted "firstPid=$firstPid"
} finally {
    Write-Step "cleanup"
    if (-not (Test-ServiceIsOurs -Name $ServiceName -Sandbox $Sandbox)) {
        Write-Host "REFUSING to remove service '$ServiceName': registered at '$(Get-RegisteredServicePath -Name $ServiceName)'" -ForegroundColor Red
        $Failures += "cleanup refused"
    } else {
        Remove-Service
        Start-Sleep -Seconds 2
        Assert-True "service removed" (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue))
    }

    Remove-Item -LiteralPath $Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    Assert-True "sandbox removed" (-not (Test-Path -LiteralPath $Sandbox)) $Sandbox
}

Write-Host ""
if ($Failures.Count -eq 0) {
    Write-Host "e2e OK"
    exit 0
}

Write-Host "e2e FAILED: $($Failures -join '; ')" -ForegroundColor Red
exit 1
