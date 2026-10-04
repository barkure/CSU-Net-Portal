$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$HomeDir = $HOME
$ConfigPath = if ($env:CONFIG_FILE) { $env:CONFIG_FILE } else { Join-Path $HomeDir ".config\csu-autoauth\config.ps1" }
$DataDir = if ($env:DATA_DIR) { $env:DATA_DIR } else { Join-Path $HomeDir ".local\share\csu-autoauth" }
$LogFile = if ($env:LOG_FILE) { $env:LOG_FILE } else { Join-Path $DataDir "csu-autoauth.log" }
$LogToStdout = if ($env:LOG_TO_STDOUT) { $env:LOG_TO_STDOUT } else { "1" }

$USERNAME = ""
$PASSWORD = ""
$TYPE = "1"
$INTERVAL = 10

if (Test-Path -LiteralPath $ConfigPath) {
    . $ConfigPath
}

$NetSuffixMap = @{
    "1" = "cmccn"
    "2" = "unicomn"
    "3" = "telecomn"
    "4" = ""
}

function Get-TimeStamp {
    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Get-LogColor {
    param([string]$Message)

    switch -Wildcard ($Message) {
        "Network up" { return "Green" }
        "Network down" { return "Red" }
        "Triggering authentication..." { return "Yellow" }
        "Login successful:*" { return "Green" }
        "Login failed:*" { return "Red" }
        "Start monitoring*" { return "Cyan" }
        "Authenticating as:*" { return "DarkCyan" }
        default { return "" }
    }
}

function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -ItemType File -Path $LogFile -Force | Out-Null
    }
}

# 控制台输出带颜色；日志文件始终为无颜色的纯文本。
function Write-Log {
    param([string]$Message)

    $line = "[$(Get-TimeStamp)] $Message"
    if ($LogToStdout -eq "1") {
        $color = Get-LogColor -Message $Message
        if ($color) {
            Write-Host $line -ForegroundColor $color
        } else {
            Write-Host $line
        }
    }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Test-Config {
    if ([string]::IsNullOrWhiteSpace($USERNAME) -or [string]::IsNullOrWhiteSpace($PASSWORD)) {
        throw "Missing USERNAME or PASSWORD in $ConfigPath"
    }

    if ([string]$TYPE -notin @("1", "2", "3", "4")) {
        throw "TYPE must be one of 1, 2, 3, 4 in $ConfigPath (got '$TYPE')"
    }

    $intervalText = [string]$INTERVAL
    if ($intervalText -notmatch '^\d+$') {
        throw "INTERVAL must be a positive integer in $ConfigPath"
    }

    $script:INTERVAL = [int]$intervalText
    if ($script:INTERVAL -le 0) {
        throw "INTERVAL must be greater than 0 in $ConfigPath"
    }
}

function Get-UserAccount {
    $suffix = $NetSuffixMap[[string]$TYPE]
    if ($suffix) {
        return "$USERNAME@$suffix"
    }
    return $USERNAME
}

function Test-Online {
    try {
        $response = & curl.exe -fsS --max-time 5 "http://captive.apple.com/hotspot-detect.html" 2>$null
        return $response -match "Success"
    } catch {
        return $false
    }
}

# 解析 eportal 登录响应：返回 @{ Success = <bool>; Message = <string> }。
function Get-LoginResponseMessage {
    param([string]$Response)

    if ([string]::IsNullOrWhiteSpace($Response)) {
        return @{ Success = $false; Message = "empty response" }
    }

    try {
        $data = $Response | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return @{ Success = $false; Message = $Response }
    }

    $message = if ($null -ne $data.msg) { [string]$data.msg } else { "" }

    if ([string]$data.result -eq "1") {
        if ([string]::IsNullOrWhiteSpace($message)) { $message = "Login successful" }
        return @{ Success = $true; Message = $message }
    }

    if ([string]::IsNullOrWhiteSpace($message)) { $message = $Response }
    return @{ Success = $false; Message = $message }
}

function Invoke-Login {
    $userAccount = Get-UserAccount
    $url = "https://10.1.1.1:802/eportal/portal/login"

    Write-Log "Authenticating as: $userAccount"
    try {
        $response = & curl.exe -k -fsS -G $url `
            --data-urlencode "user_account=$userAccount" `
            --data-urlencode "user_password=$PASSWORD" 2>&1
    } catch {
        $response = $_.Exception.Message
    }

    $parsed = Get-LoginResponseMessage -Response (($response | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if ($parsed.Success) {
        Write-Log "Login successful: $($parsed.Message)"
    } else {
        Write-Log "Login failed: $($parsed.Message)"
    }
}

# CSU_TESTING=1 时只加载函数定义，不进入监控循环（与 shell 版保持一致，便于单元测试）。
if ($env:CSU_TESTING -ne "1") {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        throw "curl.exe not found. Windows 10 1803+ is required."
    }

    Test-Config
    Initialize-LogFile
    Write-Log "Start monitoring network status (every ${INTERVAL}s)..."
    $LastStatus = ""

    while ($true) {
        if (Test-Online) {
            $CurrentStatus = "up"
            if ($LastStatus -ne $CurrentStatus) {
                Write-Log "Network up"
                $LastStatus = $CurrentStatus
            }
        } else {
            $CurrentStatus = "down"
            if ($LastStatus -ne $CurrentStatus) {
                Write-Log "Network down"
                $LastStatus = $CurrentStatus
            }
            Write-Log "Triggering authentication..."
            Invoke-Login
        }

        Start-Sleep -Seconds $INTERVAL
    }
}
