#!/bin/sh
# --data-urlencode：静态 + mock 功能。

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n' "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

check_urlencode_flag() {
    label="$1"
    script="$2"

    if grep -qF -- '--data-urlencode "user_account=' "$script" && \
       grep -qF -- '--data-urlencode "user_password=' "$script"; then
        pass "$label: 使用 --data-urlencode 传递凭据"
    else
        fail "$label: 应使用 --data-urlencode 传递凭据" "--data-urlencode flag missing in login()"
    fi

    if grep -qF -- '-d "user_account=' "$script" || \
       grep -qF -- '-d "user_password=' "$script"; then
        fail "$label: 不应使用裸 -d 传递凭据" "found raw -d parameter"
    else
        pass "$label: 已无裸 -d 参数"
    fi
}

check_urlencode_flag "sh/common/csu-net-auth.sh" "$REPO_ROOT/sh/common/csu-net-auth.sh"
check_urlencode_flag "sh/openwrt/csu-net-auth.sh" "$REPO_ROOT/sh/openwrt/csu-net-auth.sh"

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

    printf 'USERNAME="20230001"\nPASSWORD="p@ss&w=rd+!"\nTYPE="1"\n' \
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

run_functional_test "sh/common/csu-net-auth.sh" "$REPO_ROOT/sh/common/csu-net-auth.sh"
# openwrt 的 UCI 依赖不在本测试范围内（仅调用 login），/lib/functions.sh 缺失时脚本会自行跳过加载
run_functional_test "sh/openwrt/csu-net-auth.sh" "$REPO_ROOT/sh/openwrt/csu-net-auth.sh"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
