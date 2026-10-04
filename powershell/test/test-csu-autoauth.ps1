#Requires -Version 5.1
# 测试：PowerShell 版配置校验与登录响应解析
#
# 用法：
#   pwsh -NoProfile -File powershell/test/test-csu-autoauth.ps1
#
# 每个用例都在独立子进程中执行（.ps1 脚本没有 CSU_TESTING=1 之外的可注入点，
# 且需要避免上一条用例的变量污染下一条）。

$ErrorActionPreference = "Stop"

$ScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "common/csu-autoauth.ps1"

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    Write-Host "FAIL: cannot find $ScriptPath"
    exit 1
}

$PassCount = 0
$FailCount = 0
$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("csu-autoauth-ps-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

$PwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $PwshPath) {
    $PwshPath = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
}
if (-not $PwshPath) {
    Write-Host "FAIL: neither pwsh nor powershell.exe found"
    exit 1
}

function Write-Pass {
    param([string]$Message)
    Write-Host "PASS: $Message"
    $script:PassCount++
}

function Write-Fail {
    param([string]$Message, [string]$Expected, [string]$Actual)
    Write-Host "FAIL: $Message"
    Write-Host "  expected: $Expected"
    Write-Host "  actual:   $Actual"
    $script:FailCount++
}

# 生成子进程用例：dot-source 目标脚本后执行 $Body，只输出一行结果。
function New-Harness {
    param([string]$Name, [string]$Body)

    $path = Join-Path $WorkDir "$Name.ps1"
    $content = @(
        'param([string]$Target)'
        '$ErrorActionPreference = "Stop"'
        '. $Target'
        $Body
    )
    [System.IO.File]::WriteAllText($path, ($content -join "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    return $path
}

function Invoke-Harness {
    param([string]$HarnessPath, [hashtable]$Env = @{}, [string]$Target = $ScriptPath)

    $env:CSU_TESTING = "1"
    $env:LOG_TO_STDOUT = "0"
    $env:DATA_DIR = $WorkDir
    $env:LOG_FILE = Join-Path $WorkDir "csu-autoauth.log"
    $env:CSU_SERVICE_NAME = ""

    foreach ($key in $Env.Keys) {
        Set-Item -Path "env:$key" -Value $Env[$key]
    }

    $output = & $PwshPath -NoProfile -ExecutionPolicy Bypass -File $HarnessPath -Target $Target 2>&1
    return (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
}

# ── 配置校验 ─────────────────────────────────────────────────────────────────

$configHarness = New-Harness -Name "run-config" -Body @'
try {
    Test-Config
    Write-Output "OK"
} catch {
    Write-Output ("ERR:" + $_.Exception.Message)
}
'@

function Test-ConfigCase {
    param(
        [string]$Label,
        [string]$ConfigContent,
        [bool]$ExpectValid,
        [string]$ExpectFragment
    )

    $configPath = Join-Path $WorkDir "csu-config.ps1"
    # 与安装器保持一致：带 BOM 的 UTF-8
    [System.IO.File]::WriteAllText($configPath, $ConfigContent, (New-Object System.Text.UTF8Encoding($true)))

    $output = Invoke-Harness -HarnessPath $configHarness -Env @{ CONFIG_FILE = $configPath }

    $ok = $false
    if ($ExpectValid) {
        $ok = $output.Contains("OK")
    } else {
        $ok = $output.StartsWith("ERR:") -and $output.Contains($ExpectFragment)
    }

    if ($ok) {
        Write-Pass "config [$Label] -> $output"
    } else {
        Write-Fail "config [$Label]" "valid=$ExpectValid fragment='$ExpectFragment'" $output
    }
}

Test-ConfigCase -Label "valid config" -ExpectValid $true -ExpectFragment "" -ConfigContent @'
$USERNAME = "20230001"
$PASSWORD = "ok"
$TYPE = "1"
$INTERVAL = 10
'@

Test-ConfigCase -Label "interval as string" -ExpectValid $true -ExpectFragment "" -ConfigContent @'
$USERNAME = "20230001"
$PASSWORD = "ok"
$TYPE = "4"
$INTERVAL = "15"
'@

foreach ($badType in @("9", "cmcc", "", "5")) {
    $config = @"
`$USERNAME = "20230001"
`$PASSWORD = "ok"
`$TYPE = "$badType"
`$INTERVAL = 10
"@
    Test-ConfigCase -Label "TYPE='$badType'" -ExpectValid $false -ExpectFragment "TYPE must be one of 1, 2, 3, 4" -ConfigContent $config
}

foreach ($badInterval in @("0", "-1", "abc", "1.5")) {
    $config = @"
`$USERNAME = "20230001"
`$PASSWORD = "ok"
`$TYPE = "1"
`$INTERVAL = "$badInterval"
"@
    Test-ConfigCase -Label "INTERVAL='$badInterval'" -ExpectValid $false -ExpectFragment "INTERVAL" -ConfigContent $config
}

Test-ConfigCase -Label "missing credentials" -ExpectValid $false -ExpectFragment "Missing USERNAME or PASSWORD" -ConfigContent @'
$USERNAME = ""
$PASSWORD = ""
$TYPE = "1"
$INTERVAL = 10
'@

# ── 登录响应解析 ─────────────────────────────────────────────────────────────

$responseHarness = New-Harness -Name "run-response" -Body @'
$r = Get-LoginResponseMessage -Response $env:CSU_RESPONSE
if ($r.Success) { Write-Output ("OK:" + $r.Message) } else { Write-Output ("ERR:" + $r.Message) }
'@

function Test-ResponseCase {
    param(
        [string]$Label,
        [string]$Response,
        [string]$ExpectPrefix,
        [string]$ExpectMessage
    )

    $env:CSU_RESPONSE = $Response
    $output = Invoke-Harness -HarnessPath $responseHarness

    if ($output -eq "$ExpectPrefix$ExpectMessage") {
        Write-Pass "response [$Label] -> $output"
    } else {
        Write-Fail "response [$Label]" "$ExpectPrefix$ExpectMessage" $output
    }
}

Test-ResponseCase -Label "result numeric 1" -Response '{"result":1,"msg":"ok"}' -ExpectPrefix "OK:" -ExpectMessage "ok"
Test-ResponseCase -Label "result string 1" -Response '{"result":"1","msg":"ok"}' -ExpectPrefix "OK:" -ExpectMessage "ok"
Test-ResponseCase -Label "spaced json" -Response '{ "result" : 1 , "msg" : "ok" }' -ExpectPrefix "OK:" -ExpectMessage "ok"
Test-ResponseCase -Label "success without msg" -Response '{"result":1}' -ExpectPrefix "OK:" -ExpectMessage "Login successful"
Test-ResponseCase -Label "failure with msg" -Response '{"result":0,"msg":"bad password"}' -ExpectPrefix "ERR:" -ExpectMessage "bad password"
Test-ResponseCase -Label "failure without msg" -Response '{"result":0}' -ExpectPrefix "ERR:" -ExpectMessage '{"result":0}'
Test-ResponseCase -Label "non json" -Response '<html>502 Bad Gateway</html>' -ExpectPrefix "ERR:" -ExpectMessage "<html>502 Bad Gateway</html>"
Test-ResponseCase -Label "empty" -Response '' -ExpectPrefix "ERR:" -ExpectMessage "empty response"

# ── Invoke-Login 端到端（用同名函数替身拦截 curl.exe，不真的联网） ────────

$loginHarness = New-Harness -Name "run-login" -Body @'
function curl.exe {
    $args | Set-Content -LiteralPath $env:CSU_STUB_ARGS_FILE
    $env:CSU_STUB_RESPONSE
}
$USERNAME = "20230001"
$PASSWORD = "s3cret"
$TYPE = "2"
Initialize-LogFile
Invoke-Login
"ARGS:" + ((Get-Content -LiteralPath $env:CSU_STUB_ARGS_FILE) -join " ")
"LOG:" + (Get-Content -LiteralPath $env:LOG_FILE -Tail 1)
'@

function Test-LoginCase {
    param(
        [string]$Label,
        [string]$StubResponse,
        [string]$ExpectLogFragment,
        [string]$ExpectArgsFragment
    )

    $env:CSU_STUB_RESPONSE = $StubResponse
    $argsFile = Join-Path $WorkDir "curl-args-$([Guid]::NewGuid().ToString("N")).txt"
    $logFile = Join-Path $WorkDir "login-$([Guid]::NewGuid().ToString("N")).log"

    $output = Invoke-Harness -HarnessPath $loginHarness -Env @{
        CSU_STUB_RESPONSE = $StubResponse
        CSU_STUB_ARGS_FILE = $argsFile
        LOG_FILE = $logFile
    }

    if ($output.Contains($ExpectLogFragment) -and $output.Contains($ExpectArgsFragment)) {
        Write-Pass "invoke-login [$Label] -> $($output -replace "`n", " ")"
    } else {
        Write-Fail "invoke-login [$Label]" "log contains '$ExpectLogFragment' and args contains '$ExpectArgsFragment'" $output
    }
}

Test-LoginCase -Label "success" `
    -StubResponse '{"result":1,"msg":"logged in"}' `
    -ExpectLogFragment "Login successful: logged in" `
    -ExpectArgsFragment "user_account=20230001@unicomn"

Test-LoginCase -Label "failure" `
    -StubResponse '{"result":0,"msg":"bad password"}' `
    -ExpectLogFragment "Login failed: bad password" `
    -ExpectArgsFragment "user_account=20230001@unicomn"

Test-LoginCase -Label "non json" `
    -StubResponse '<html>502</html>' `
    -ExpectLogFragment "Login failed: <html>502</html>" `
    -ExpectArgsFragment "user_password=s3cret"

# ── 安装器：服务模式（仅 Windows；CI 的 Linux runner 会跳过） ───────────────

$IsWindowsHost = ($env:OS -eq "Windows_NT")

if (-not $IsWindowsHost) {
    Write-Host "SKIP: install-main.ps1 service tests (Windows only)"
} else {
    $InstallMainPath = Join-Path (Split-Path -Parent $PSScriptRoot) "common/install-main.ps1"

    $installHarness = New-Harness -Name "run-install" -Body @'
Set-Content -LiteralPath $env:CSU_XML_OUT -Value (New-ServiceXml) -Encoding UTF8
Write-Output ("SERVICENAME|" + $ServiceName)
Write-Output ("EXE|" + $ServiceExe)
Write-Output ("XML|" + $ServiceXml)
'@

    function Test-ServiceModeCase {
        param(
            [string]$Label,
            [hashtable]$Env,
            [string]$ExpectServiceName
        )

        $xmlOut = Join-Path $WorkDir "service-$([Guid]::NewGuid().ToString("N")).xml"
        # 隔离主机上真实的 config.ps1，只关心路径/XML 推导
        $extra = @{ CSU_XML_OUT = $xmlOut; CONFIG_FILE = (Join-Path $WorkDir "nonexistent-config.ps1") }
        foreach ($key in $Env.Keys) { $extra[$key] = $Env[$key] }

        $output = Invoke-Harness -HarnessPath $installHarness -Env $extra -Target $InstallMainPath

        $fields = @{}
        foreach ($line in $output -split "`n") {
            $parts = $line.Split('|', 2)
            if ($parts.Count -eq 2) { $fields[$parts[0].Trim()] = $parts[1].Trim() }
        }

        $problems = @()
        if ($fields["SERVICENAME"] -ne $ExpectServiceName) { $problems += "service name '$($fields['SERVICENAME'])' != '$ExpectServiceName'" }

        $expectedExeName = "$ExpectServiceName-service.exe"
        if ((Split-Path -Leaf $fields["EXE"]) -ne $expectedExeName) { $problems += "exe '$($fields['EXE'])' != '$expectedExeName'" }
        # WinSW 要求 xml 与 exe 同基名
        if ((Split-Path -Leaf $fields["XML"]) -ne "$ExpectServiceName-service.xml") { $problems += "xml '$($fields['XML'])' does not share the exe base name" }

        if (-not (Test-Path -LiteralPath $xmlOut)) {
            $problems += "xml not written to $xmlOut"
        } else {
            try {
                [xml]$doc = Get-Content -LiteralPath $xmlOut -Raw
            } catch {
                $problems += "xml parse failed: $($_.Exception.Message)"
            }

            if ($doc) {
                if ($doc.service.id -ne $ExpectServiceName) { $problems += "xml id '$($doc.service.id)' != '$ExpectServiceName'" }
                if ($doc.service.startmode -ne "Automatic") { $problems += "startmode '$($doc.service.startmode)'" }
                if (@($doc.service.onfailure).Count -ne 2) { $problems += "onfailure count $(@($doc.service.onfailure).Count) != 2" }
                if ($doc.service.resetfailure -ne "1 hour") { $problems += "resetfailure '$($doc.service.resetfailure)'" }
                if ($doc.service.stoptimeout -ne "10 sec") { $problems += "stoptimeout '$($doc.service.stoptimeout)'" }
                if (-not $doc.service.executable.EndsWith("powershell.exe")) { $problems += "executable '$($doc.service.executable)'" }
                if ($doc.service.arguments -notlike '* -File "*') { $problems += "arguments '$($doc.service.arguments)' missing -File <script>" }
                if ($doc.service.log.mode -ne "roll-by-size") { $problems += "log mode '$($doc.service.log.mode)'" }
                if ($doc.service.log.sizeThreshold -ne "10240") { $problems += "sizeThreshold '$($doc.service.log.sizeThreshold)'" }
                if ($doc.service.log.keepFiles -ne "4") { $problems += "keepFiles '$($doc.service.log.keepFiles)'" }

                $serviceEnv = @{}
                foreach ($item in @($doc.service.env)) { $serviceEnv[$item.name] = $item.value }
                foreach ($key in @("CONFIG_FILE", "DATA_DIR", "LOG_FILE")) {
                    if (-not $serviceEnv[$key]) { $problems += "env $key missing" }
                }
                if ($serviceEnv["LOG_TO_STDOUT"] -ne "1") { $problems += "env LOG_TO_STDOUT '$($serviceEnv['LOG_TO_STDOUT'])'" }
                if ($serviceEnv["LOG_FILE"] -notlike '*.log') { $problems += "env LOG_FILE '$($serviceEnv['LOG_FILE'])'" }
            }
        }

        if ($problems.Count -eq 0) {
            Write-Pass "service [$Label] service=$ExpectServiceName xml ok"
        } else {
            Write-Fail "service [$Label]" "no problems" ($problems -join "; ")
        }
    }

    $saveConfigHarness = New-Harness -Name "save-config" -Body @'
$BinDir = Join-Path $env:DATA_DIR "bin"
$ConfigDir = Join-Path $env:DATA_DIR "config"
$DataDir = Join-Path $env:DATA_DIR "data"
$ScriptPath = Join-Path $BinDir "csu-autoauth.ps1"
$ConfigPath = Join-Path $ConfigDir "config.ps1"
$LogFile = Join-Path $DataDir "csu-autoauth.log"
function Invoke-WebRequest { param($Uri, $OutFile, [switch]$UseBasicParsing) }
$USERNAME = 'student$01'
$PASSWORD = 'a''b"c$d`e$(Get-Date)中文'
$TYPE = "2"
$INTERVAL = 10
$expectedUser = $USERNAME
$expectedPassword = $PASSWORD
Install-CommonFiles
$USERNAME = ""
$PASSWORD = ""
. $ConfigPath
if ($USERNAME -eq $expectedUser -and $PASSWORD -eq $expectedPassword) {
    Write-Output "OK: credentials preserved"
} else { throw "Credentials changed after loading saved config" }
'@
    $savedConfigOutput = Invoke-Harness -HarnessPath $saveConfigHarness -Target $InstallMainPath
    if ($savedConfigOutput -eq "OK: credentials preserved") {
        Write-Pass "saved credentials preserve special characters"
    } else {
        Write-Fail "saved credentials" "OK: credentials preserved" $savedConfigOutput
    }

    Test-ServiceModeCase -Label "default" -Env @{} -ExpectServiceName "csu-autoauth"
    Test-ServiceModeCase -Label "custom service name" -Env @{ CSU_SERVICE_NAME = "csu-autoauth-svctest" } -ExpectServiceName "csu-autoauth-svctest"
    Test-ServiceModeCase -Label "xml escaping" -Env @{ CSU_SERVICE_NAME = "csu&aouth-test" } -ExpectServiceName "csu&aouth-test"
}

# ── 编码门禁：.ps1 必须带 UTF-8 BOM ──────────────────────────────────
# Windows PowerShell 5.1 对无 BOM 的文件按 ANSI(GBK) 解码，中文注释/字符串会解析错乱，
# 而 Windows 服务正是用 powershell.exe (5.1) 跑这个脚本；CI 上的 pwsh 7 默认 UTF-8，
# 会掩盖这个问题，所以这里显式断言 BOM 存在。

$PowerShellRootForEncoding = Join-Path (Split-Path -Parent $PSScriptRoot) "."
$encodingTargets = @(Get-ChildItem -Path $PowerShellRootForEncoding -Filter "*.ps1" -Recurse) +
                   @(Get-ChildItem -Path $PowerShellRootForEncoding -Filter "*.ps1.example" -Recurse)

foreach ($file in $encodingTargets) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

    if ($hasBom) {
        Write-Pass "bom [$($file.Name)] UTF-8 BOM present"
    } else {
        Write-Fail "bom [$($file.Name)]" "UTF-8 BOM (EF BB BF)" "no BOM"
    }
}

# ── 语法解析门禁（所有 ps1） ─────────────────────────────────────────────────

$PowerShellRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "."
foreach ($file in Get-ChildItem -Path $PowerShellRoot -Filter *.ps1 -Recurse) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null

    if ($errors.Count -gt 0) {
        Write-Fail "parse [$($file.Name)]" "0 syntax errors" "$($errors.Count) errors: $($errors[0].Message)"
    } else {
        Write-Pass "parse [$($file.Name)] no syntax errors"
    }
}

Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "$PassCount passed, $FailCount failed"
if ($FailCount -gt 0) { exit 1 }
