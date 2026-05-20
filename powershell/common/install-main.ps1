$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRawUrl = if ($env:REPO_RAW_URL) { $env:REPO_RAW_URL } else { "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main" }
$HomeDir = $HOME
$BinDir = Join-Path $HomeDir ".local\bin"
$ConfigDir = Join-Path $HomeDir ".config\csu-autoauth"
$DataDir = Join-Path $HomeDir ".local\share\csu-autoauth"
$ScriptPath = Join-Path $BinDir "csu-autoauth.ps1"
$ConfigPath = Join-Path $ConfigDir "config.ps1"
$LogFile = Join-Path $DataDir "csu-autoauth.log"
$StartupDir = [Environment]::GetFolderPath("Startup")
$LauncherPath = Join-Path $StartupDir "csu-autoauth.vbs"

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
    Invoke-WebRequest -Uri "$RepoRawUrl/powershell/common/csu-autoauth.ps1" -OutFile $ScriptPath

    @(
        '$USERNAME = "{0}"' -f $USERNAME.Replace('"', '""')
        '$PASSWORD = "{0}"' -f $PASSWORD.Replace('"', '""')
        '$TYPE = "{0}"' -f $TYPE
        '$INTERVAL = {0}' -f $INTERVAL
    ) | Set-Content -Path $ConfigPath -Encoding UTF8

    New-Item -ItemType File -Path $LogFile -Force | Out-Null
}

function Install-Startup {
    $launcherContent = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$ScriptPath""", 0, False
"@

    Set-Content -Path $LauncherPath -Value $launcherContent -Encoding ASCII
}

function Restart-AuthProcess {
    $runningProcesses = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^powershell(\.exe)?$' -and $_.CommandLine -like "*$ScriptPath*"
    }

    foreach ($process in $runningProcesses) {
        Stop-Process -Id $process.ProcessId -Force
    }

    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $ScriptPath
    ) | Out-Null
}

Collect-Config
Install-CommonFiles
Install-Startup
Restart-AuthProcess

Write-Output "Installed script: $ScriptPath"
Write-Output "Installed config: $ConfigPath"
Write-Output "Installed startup launcher: $LauncherPath"
Write-Output "Log file: $LogFile"
