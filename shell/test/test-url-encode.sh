#!/bin/sh
# 测试：login() 使用 --data-urlencode 正确传递含特殊字符的凭据
# 分两层：
#   Layer 1 (静态) — 确认源码使用了 --data-urlencode
#   Layer 2 (功能) — 注入 mock curl，验证实际调用参数（需要 CSU_TESTING 守卫）

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n' "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# ── Layer 1: 静态检查 ─────────────────────────────────────────────────────────

check_urlencode_flag() {
    label="$1"
    script="$2"

    if grep -qF -- '--data-urlencode "user_account=' "$script" && \
       grep -qF -- '--data-urlencode "user_password=' "$script"; then
        pass "$label: 使用 --data-urlencode 传递凭据"
    else
        fail "$label: 应使用 --data-urlencode 传递凭据" "--data-urlencode flag missing in login()"
    fi

    # 反向：确认裸 -d 已不存在
    if grep -qF -- '-d "user_account=' "$script" || \
       grep -qF -- '-d "user_password=' "$script"; then
        fail "$label: 不应使用裸 -d 传递凭据" "found raw -d parameter"
    else
        pass "$label: 已无裸 -d 参数"
    fi
}

check_urlencode_flag "shell/common/csu-autoauth.sh" "$REPO_ROOT/shell/common/csu-autoauth.sh"
check_urlencode_flag "openwrt/csu-autoauth.sh"      "$REPO_ROOT/openwrt/csu-autoauth.sh"

# ── Layer 2: 功能测试（需要 CSU_TESTING 守卫） ────────────────────────────────

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
exit 0
MOCK
    chmod +x "$mock_curl"

    printf 'USERNAME="20230001"\nPASSWORD="p@ss&w=rd+!"\nTYPE="1"\nINTERVAL="10"\n' \
        > "$tmpdir/config.conf"

    wrapper="$tmpdir/runner.sh"
    printf '. "%s"\nlogin\n' "$script" > "$wrapper"

    # 通过后台+sleep强制超时（兼容无 timeout 命令的 macOS）
    (
        DATA_DIR="$tmpdir" \
        LOG_FILE="$tmpdir/test.log" \
        CONFIG_FILE="$tmpdir/config.conf" \
        CURL_ARGS_FILE="$args_log" \
        CSU_TESTING=1 \
        PATH="$tmpdir:$PATH" \
        sh "$wrapper" > "$tmpdir/out.log" 2>&1 &
        WRAPPER_PID=$!
        sleep 3
        kill "$WRAPPER_PID" 2>/dev/null || true
        wait "$WRAPPER_PID" 2>/dev/null || true
    )

    if [ ! -f "$args_log" ]; then
        fail "$label 功能测试: mock curl 未被调用（缺少 CSU_TESTING 守卫？）" "curl not invoked"
        trap - EXIT; rm -rf "$tmpdir"
        return
    fi

    if grep -qF -- '--data-urlencode' "$args_log"; then
        pass "$label 功能测试: curl 收到 --data-urlencode 参数"
    else
        fail "$label 功能测试: curl 未收到 --data-urlencode" "$(cat "$args_log")"
    fi

    trap - EXIT
    rm -rf "$tmpdir"
}

run_functional_test "shell/common/csu-autoauth.sh" "$REPO_ROOT/shell/common/csu-autoauth.sh"
# openwrt 依赖 /lib/functions.sh（OpenWrt 专属），非 OpenWrt 环境跳过功能测试
if [ -f /lib/functions.sh ]; then
    run_functional_test "openwrt/csu-autoauth.sh" "$REPO_ROOT/openwrt/csu-autoauth.sh"
else
    printf 'SKIP: openwrt/csu-autoauth.sh 功能测试（非 OpenWrt 环境）\n'
fi

# ── 汇总 ──────────────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
