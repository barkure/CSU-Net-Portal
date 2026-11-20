#!/bin/sh
# 测试：login() / Invoke-Login 的 curl 调用设置了连接与总超时，避免认证门户无响应时阻塞轮询

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n' "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# ── Layer 1: 静态检查 ─────────────────────────────────────────────────────────

check_timeout_flags() {
    label="$1"
    script="$2"

    if grep -qE 'curl(\.exe)? -k -fsS .*--connect-timeout [0-9]+.*--max-time [0-9]+' "$script"; then
        pass "$label: login curl 设置了 --connect-timeout 与 --max-time"
    else
        fail "$label: login curl 应设置 --connect-timeout 与 --max-time" "missing timeout flags in login()"
    fi
}

check_timeout_flags "shell/common/csu-autoauth.sh"      "$REPO_ROOT/shell/common/csu-autoauth.sh"
check_timeout_flags "openwrt/csu-autoauth.sh"           "$REPO_ROOT/openwrt/csu-autoauth.sh"
check_timeout_flags "powershell/common/csu-autoauth.ps1" "$REPO_ROOT/powershell/common/csu-autoauth.ps1"

# ── Layer 2: 功能测试（注入 mock curl 验证实际参数） ──────────────────────────

run_functional_test() {
    label="$1"
    script="$2"

    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" EXIT

    mock_curl="$tmpdir/curl"
    args_log="$tmpdir/curl_args"

    cat > "$mock_curl" << 'MOCK'
#!/bin/sh
printf '%s\n' "$@" > "$CURL_ARGS_FILE"
printf '%s' '{"result":"1","msg":"ok"}'
exit 0
MOCK
    chmod +x "$mock_curl"

    printf 'USERNAME="20230001"\nPASSWORD="secret"\nTYPE="1"\nINTERVAL="10"\n' \
        > "$tmpdir/config.conf"

    wrapper="$tmpdir/runner.sh"
    printf '. "%s"\nlogin\n' "$script" > "$wrapper"

    (
        DATA_DIR="$tmpdir" \
        LOG_DIR="$tmpdir" \
        LOG_FILE="$tmpdir/test.log" \
        CONFIG_FILE="$tmpdir/config.conf" \
        CURL_ARGS_FILE="$args_log" \
        CSU_TESTING=1 \
        PATH="$tmpdir:$PATH" \
        sh "$wrapper" > "$tmpdir/out.log" 2>&1 &
        WRAPPER_PID=$!
        sleep 2
        kill "$WRAPPER_PID" 2>/dev/null || true
        wait "$WRAPPER_PID" 2>/dev/null || true
    )

    if [ ! -f "$args_log" ]; then
        fail "$label 功能测试: mock curl 未被调用" "curl not invoked"
        trap - EXIT; rm -rf "$tmpdir"
        return
    fi

    if grep -qF -- '--connect-timeout' "$args_log" && grep -qF -- '--max-time' "$args_log"; then
        pass "$label 功能测试: curl 收到 --connect-timeout 与 --max-time 参数"
    else
        fail "$label 功能测试: curl 缺少超时参数" "$(cat "$args_log")"
    fi

    trap - EXIT
    rm -rf "$tmpdir"
}

run_functional_test "shell/common/csu-autoauth.sh" "$REPO_ROOT/shell/common/csu-autoauth.sh"
run_functional_test "openwrt/csu-autoauth.sh"      "$REPO_ROOT/openwrt/csu-autoauth.sh"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
