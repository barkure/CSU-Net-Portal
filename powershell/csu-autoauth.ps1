$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$configDir = Join-Path $HOME ".config\csu-autoauth"
$configPath = Join-Path $configDir "config.ps1"

# === User configuration ===
$USERNAME = ""
$PASSWORD = ""
$TYPE = "1"
$INTERVAL = 10

if (Test-Path -LiteralPath $configPath) {
    . $configPath
}

# === Log location ===
$defaultLogDir = Join-Path $env:LOCALAPPDATA "csu-autoauth"
$LOG_DIR = if ($env:LOG_DIR) { $env:LOG_DIR } else { $defaultLogDir }
$LOG_FILE = if ($env:LOG_FILE) { $env:LOG_FILE } else { Join-Path $LOG_DIR "csu-autoauth.log" }

$NET_SUFFIX_MAP = @{
    "1" = "cmccn"
    "2" = "unicomn"
    "3" = "telecomn"
    "4" = ""
}

function Get-TimeStamp {
    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }
    "" | Set-Content -Path $LOG_FILE -Encoding UTF8
}

function Write-Log {
    param([string]$Message)

    $line = "[$(Get-TimeStamp)] $Message"
    Write-Output $line
    Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
}

function Test-Config {
    if ([string]::IsNullOrWhiteSpace($USERNAME) -or [string]::IsNullOrWhiteSpace($PASSWORD)) {
        throw "Missing USERNAME or PASSWORD in $configPath"
    }
}

function Get-UserAccount {
    $suffix = $NET_SUFFIX_MAP[$TYPE]
    if ($suffix) {
        return "$USERNAME@$suffix"
    }
    return $USERNAME
}

function Test-Online {
    try {
        $response = & curl.exe -s --max-time 5 "http://captive.apple.com"
        return $response -match "Success"
    } catch {
        return $false
    }
}

function Invoke-Login {
    $userAccount = Get-UserAccount
    $url = "https://10.1.1.1:802/eportal/portal/login"

    Write-Log "Authenticating as: $userAccount"
    $response = & curl.exe -k -s -G $url `
        --data-urlencode "user_account=$userAccount" `
        --data-urlencode "user_password=$PASSWORD"
    Write-Log "Login response: $response"
}

Test-Config
Initialize-LogFile
Write-Log "Start monitoring network status (every ${INTERVAL}s)..."
$lastStatus = ""

while ($true) {
    if (Test-Online) {
        $currentStatus = "up"
        if ($lastStatus -ne $currentStatus) {
            Write-Log "Network up"
            $lastStatus = $currentStatus
        }
    } else {
        $currentStatus = "down"
        if ($lastStatus -ne $currentStatus) {
            Write-Log "Network down"
            $lastStatus = $currentStatus
        }
        Write-Log "Triggering authentication..."
        Invoke-Login
    }

    Start-Sleep -Seconds $INTERVAL
}
