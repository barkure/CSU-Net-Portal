$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$HomeDir = $HOME
$BinDir = Join-Path $HomeDir ".local\bin"
$ConfigDir = Join-Path $HomeDir ".config\csu-autoauth"
$DataDir = Join-Path $HomeDir ".local\share\csu-autoauth"
$ScriptPath = Join-Path $BinDir "csu-autoauth.ps1"
$ConfigPath = Join-Path $ConfigDir "config.ps1"
$LogFile = Join-Path $DataDir "csu-autoauth.log"
$StartupDir = [Environment]::GetFolderPath("Startup")
$LauncherPath = Join-Path $StartupDir "csu-autoauth.vbs"

# 默认安装为 Windows 服务（开机即启 + 崩溃重启，需管理员），与 Linux 的 systemd
# Restart=always / macOS 的 launchd KeepAlive 对等。
$ServiceName = if ($env:CSU_SERVICE_NAME) { $env:CSU_SERVICE_NAME } else { "csu-autoauth" }
$ServiceExeName = "$ServiceName-service.exe"
$ServiceExe = Join-Path $BinDir $ServiceExeName
$ServiceXml = Join-Path $BinDir "$ServiceName-service.xml"

# WinSW（Windows Service Wrapper，CloudBees, 2.12.0）作为服务包装器：
# x64/x86 文件随仓库提供，经 jsDelivr 下载，保留官方 release 文件的 SHA256 校验。
$WinSwVersion = "2.12.0"
$WinSwAssets = @{
    "AMD64" = @{ Name = "WinSW-x64.exe"; Sha256 = "05B82D46AD331CC16BDC00DE5C6332C1EF818DF8CEEFCD49C726553209B3A0DA" }
    "x86"   = @{ Name = "WinSW-x86.exe"; Sha256 = "0C21327463A43A61F2EFB227EC4AFD2467FDE91618CC725148C1099001CA91AE" }
}

$USERNAME = ""
$PASSWORD = ""
$TYPE = "1"
$INTERVAL = 10

if (Test-Path -LiteralPath $ConfigPath) {
    . $ConfigPath
}

function Prompt-WithDefault {
    param(
        [string]$Prompt,
        [string]$DefaultValue
    )

    if ([string]::IsNullOrEmpty($DefaultValue)) {
        return Read-Host $Prompt
    }

    $value = Read-Host "$Prompt [$DefaultValue]"
    if ([string]::IsNullOrEmpty($value)) {
        return $DefaultValue
    }
    return $value
}

function Prompt-Password {
    param([string]$CurrentPassword)

    if ([string]::IsNullOrEmpty($CurrentPassword)) {
        $value = Read-Host "密码"
    } else {
        $value = Read-Host "密码 [$CurrentPassword]"
    }

    if ([string]::IsNullOrEmpty($value)) {
        return $CurrentPassword
    }
    return $value
}

function Prompt-NetworkType {
    param([string]$CurrentType)

    while ($true) {
        Write-Host "网络类型:"
        Write-Host "  1) 中国移动"
        Write-Host "  2) 中国联通"
        Write-Host "  3) 中国电信"
        Write-Host "  4) 校园网"

        $selected = Prompt-WithDefault -Prompt "请选择" -DefaultValue $CurrentType
        if ($selected -in @("1", "2", "3", "4")) {
            return $selected
        }

        Write-Host "无效选项，请输入 1、2、3 或 4。"
    }
}

function Prompt-Interval {
    param([int]$CurrentInterval)

    while ($true) {
        $selected = Prompt-WithDefault -Prompt "检测间隔（秒）" -DefaultValue ([string]$CurrentInterval)
        if ($selected -match '^\d+$' -and [int]$selected -gt 0) {
            return [int]$selected
        }

        Write-Host "时间间隔必须是大于 0 的正整数。"
    }
}

function Collect-Config {
    $script:USERNAME = Prompt-WithDefault -Prompt "学号" -DefaultValue $USERNAME
    $script:PASSWORD = Prompt-Password -CurrentPassword $PASSWORD
    $script:TYPE = Prompt-NetworkType -CurrentType $TYPE
    $script:INTERVAL = Prompt-Interval -CurrentInterval $INTERVAL

    if ([string]::IsNullOrWhiteSpace($USERNAME) -or [string]::IsNullOrWhiteSpace($PASSWORD)) {
        throw "学号和密码不能为空。"
    }
}

function Install-CommonFiles {
    New-Item -ItemType Directory -Path $BinDir, $ConfigDir, $DataDir -Force | Out-Null
    Invoke-WebRequest -Uri "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/common/csu-autoauth.ps1" -OutFile $ScriptPath -UseBasicParsing

    # 必须写 UTF-8 **带 BOM**：Windows PowerShell 5.1 对无 BOM 文件按 ANSI 解码，
    # 含中文（或非 ASCII 密码）时会解析错乱。Set-Content -Encoding UTF8 在 pwsh 7 下不带 BOM。
    $configContent = @(
        "`$USERNAME = '{0}'" -f $USERNAME.Replace("'", "''")
        "`$PASSWORD = '{0}'" -f $PASSWORD.Replace("'", "''")
        '$TYPE = "{0}"' -f $TYPE
        '$INTERVAL = {0}' -f $INTERVAL
        ''
    ) -join "`r`n"
    [System.IO.File]::WriteAllText($ConfigPath, $configContent, (New-Object System.Text.UTF8Encoding($true)))

    New-Item -ItemType File -Path $LogFile -Force | Out-Null
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WinSwAsset {
    $arch = if ($env:PROCESSOR_ARCHITECTURE) { $env:PROCESSOR_ARCHITECTURE } else { "AMD64" }

    # ARM64 的 Windows 能跑 x64 build（模拟）；32 位系统用 x86 build。
    switch ($arch) {
        "AMD64" { return $WinSwAssets["AMD64"] }
        "ARM64" { return $WinSwAssets["AMD64"] }
        "x86"   { return $WinSwAssets["x86"] }
        default { throw "Unsupported processor architecture: $arch" }
    }
}

function Install-WinSw {
    $asset = Get-WinSwAsset

    if (Test-Path -LiteralPath $ServiceExe) {
        $existing = (Get-FileHash -LiteralPath $ServiceExe -Algorithm SHA256).Hash
        if ($existing -eq $asset.Sha256) {
            Write-Host "Reusing verified WinSW: $ServiceExe"
            return
        }
    }

    $url = "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/vendor/winsw/$($asset.Name)"
    $tempExe = "$ServiceExe.download"
    Remove-Item -LiteralPath $tempExe -Force -ErrorAction SilentlyContinue

    Write-Host "Downloading WinSW $WinSwVersion ($($asset.Name))..."
    Invoke-WebRequest -Uri $url -OutFile $tempExe -UseBasicParsing

    $actual = (Get-FileHash -LiteralPath $tempExe -Algorithm SHA256).Hash
    if ($actual -ne $asset.Sha256) {
        Remove-Item -LiteralPath $tempExe -Force -ErrorAction SilentlyContinue
        throw "WinSW checksum mismatch (expected $($asset.Sha256), got $actual). Aborting."
    }

    Move-Item -LiteralPath $tempExe -Destination $ServiceExe -Force
    Write-Host "WinSW verified: SHA256 $actual"
}

# WinSW 会把进度写到 stderr；PS 5.1 下 $ErrorActionPreference=Stop 会把 stderr 当终止错误，
# 所以这里临时降级并按退出码自己判定。
function Invoke-WinSw {
    param(
        [string]$Command,
        [switch]$AllowFailure
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $ServiceExe $Command 2>&1 | ForEach-Object { Write-Host "  $([string]$_)" }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    if (-not $AllowFailure -and $code -ne 0) {
        throw "WinSW $Command failed with exit code $code"
    }

    return $code
}

function New-ServiceXml {
    $powershellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

    # 服务以 LocalSystem 运行，$HOME 不是用户目录，因此路径必须通过 env 显式传入。
    return @"
<?xml version="1.0" encoding="utf-8"?>
<service>
  <id>$([System.Security.SecurityElement]::Escape($ServiceName))</id>
  <name>CSU Net AutoAuth Service</name>
  <description>自动登录中南大学校园网，保持校园网登录态</description>
  <executable>$([System.Security.SecurityElement]::Escape($powershellExe))</executable>
  <arguments>-NoProfile -ExecutionPolicy Bypass -File &quot;$([System.Security.SecurityElement]::Escape($ScriptPath))&quot;</arguments>
  <workingdirectory>$([System.Security.SecurityElement]::Escape($DataDir))</workingdirectory>
  <env name="CONFIG_FILE" value="$([System.Security.SecurityElement]::Escape($ConfigPath))" />
  <env name="DATA_DIR" value="$([System.Security.SecurityElement]::Escape($DataDir))" />
  <env name="LOG_FILE" value="$([System.Security.SecurityElement]::Escape($LogFile))" />
  <env name="LOG_TO_STDOUT" value="1" />
  <startmode>Automatic</startmode>
  <onfailure action="restart" delay="10 sec" />
  <onfailure action="restart" delay="30 sec" />
  <resetfailure>1 hour</resetfailure>
  <stoptimeout>10 sec</stoptimeout>
  <logpath>$([System.Security.SecurityElement]::Escape((Join-Path $DataDir "logs")))</logpath>
  <log mode="roll-by-size">
    <sizeThreshold>10240</sizeThreshold>
    <keepFiles>4</keepFiles>
  </log>
</service>
"@
}

function Remove-Service {
    if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
        return
    }

    if (-not (Test-Path -LiteralPath $ServiceExe)) {
        Write-Host "Service $ServiceName is registered but $ServiceExe is missing; removing via sc.exe"
        & sc.exe delete $ServiceName 2>&1 | ForEach-Object { Write-Host "  $([string]$_)" }
        return
    }

    Invoke-WinSw -Command "stop" -AllowFailure | Out-Null
    Invoke-WinSw -Command "uninstall" | Out-Null
}

function Install-Service {
    if (-not (Test-Administrator)) {
        throw "注册 Windows 服务需要管理员权限。请以管理员身份重开 PowerShell 后重试。"
    }

    Install-WinSw
    [System.IO.File]::WriteAllText($ServiceXml, (New-ServiceXml), (New-Object System.Text.UTF8Encoding($true)))

    # 清理旧版启动项和进程，避免与服务重复运行
    if (Test-Path -LiteralPath $LauncherPath) {
        Remove-Item -LiteralPath $LauncherPath -Force
        Write-Output "Removed legacy startup launcher: $LauncherPath"
    }
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^powershell(\.exe)?$' -and $_.CommandLine -like "*$ScriptPath*"
    } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
    }

    Invoke-WinSw -Command "install" | Out-Null
    Invoke-WinSw -Command "start" | Out-Null
}

# CSU_TESTING=1 时只加载函数与路径推导，不执行安装（便于单元测试）。
if ($env:CSU_TESTING -ne "1") {
    if (-not (Test-Administrator)) {
        throw "安装 Windows 服务需要管理员权限。请以管理员身份重开 PowerShell 后重试。"
    }
    Collect-Config
    # 更新脚本、配置和服务包装器前先停止并移除旧服务。
    Remove-Service
    Install-CommonFiles
    Install-Service

    Write-Output "Installed script: $ScriptPath"
    Write-Output "Installed config: $ConfigPath"
    Write-Output "Installed service: $ServiceName ($ServiceExe)"
    Write-Output "Service config: $ServiceXml"
    Write-Output "Log file: $LogFile"
}
