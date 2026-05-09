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

function Initialize-LogFile {
    if (-not (Test-Path -LiteralPath $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LogFile)) {
        New-Item -ItemType File -Path $LogFile -Force | Out-Null
    }
}

function Write-Log {
    param([string]$Message)

    $line = "[$(Get-TimeStamp)] $Message"
    if ($LogToStdout -eq "1") {
        Write-Output $line
    }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Test-Config {
    if ([string]::IsNullOrWhiteSpace($USERNAME) -or [string]::IsNullOrWhiteSpace($PASSWORD)) {
        throw "Missing USERNAME or PASSWORD in $ConfigPath"
    }

    if ($INTERVAL -isnot [int] -and $INTERVAL -isnot [long]) {
        throw "INTERVAL must be a positive integer in $ConfigPath"
    }

    if ($INTERVAL -le 0) {
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
    Write-Log "Login response: $response"
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
