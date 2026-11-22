#!/bin/sh
# login curl 超时：静态 + mock 功能。

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n' "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

extract_login_block() {
    script="$1"
    case "$script" in
        *.ps1) awk '/^function Invoke-Login \{/,/^\}/' "$script" ;;
        *)     awk '/^login\(\) \{/,/^\}/' "$script" ;;
    esac
}

check_timeout_flags() {
    label="$1"
    script="$2"
    login_block=$(extract_login_block "$script")

    if printf '%s\n' "$login_block" | grep -qE -- '--connect-timeout[[:space:]]+[1-9][0-9]*' && \
       printf '%s\n' "$login_block" | grep -qE -- '--max-time[[:space:]]+[1-9][0-9]*'; then
        pass "$label: login curl 设置了 --connect-timeout 与 --max-time"
    else
        fail "$label: login curl 应设置 --connect-timeout 与 --max-time" "missing timeout flags in login()"
    fi
}

check_timeout_flags "sh/common/csu-net-auth.sh"      "$REPO_ROOT/sh/common/csu-net-auth.sh"
check_timeout_flags "sh/openwrt/csu-net-auth.sh"     "$REPO_ROOT/sh/openwrt/csu-net-auth.sh"
check_timeout_flags "pwsh/common/csu-net-auth.ps1"   "$REPO_ROOT/pwsh/common/csu-net-auth.ps1"

has_positive_int_flag() {
    flag="$1"
    file="$2"
    awk -v flag="$flag" '
        found {
            if ($0 ~ /^[1-9][0-9]*$/) { ok = 1 }
            found = 0
            next
        }
        $0 == flag { found = 1 }
        END { exit(ok ? 0 : 1) }
    ' "$file"
}

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

    printf 'USERNAME="20230001"\nPASSWORD="secret"\nTYPE="1"\n' \
        > "$tmpdir/config.conf"

    wrapper="$tmpdir/runner.sh"
    # shell 版会读 CONFIG_FILE，openwrt 版不读 CONFIG_FILE，因此兜底注入凭据与后缀。
    cat > "$wrapper" <<EOF
. "$script"
USERNAME="\${USERNAME:-20230001}"
PASSWORD="\${PASSWORD:-secret}"
TYPE="\${TYPE:-1}"
NET_SUFFIX="\${NET_SUFFIX:-cmccn}"
login
EOF

    DATA_DIR="$tmpdir" \
    LOG_DIR="$tmpdir" \
    LOG_FILE="$tmpdir/test.log" \
    CONFIG_FILE="$tmpdir/config.conf" \
    CURL_ARGS_FILE="$args_log" \
    CSU_TESTING=1 \
    PATH="$tmpdir:$PATH" \
    sh "$wrapper" > "$tmpdir/out.log" 2>&1

    if [ ! -f "$args_log" ]; then
        fail "$label 功能测试: mock curl 未被调用" "curl not invoked"
        trap - EXIT; rm -rf "$tmpdir"
        return
    fi

    if has_positive_int_flag "--connect-timeout" "$args_log" && \
       has_positive_int_flag "--max-time" "$args_log" && \
       grep -qF -- "user_account=20230001@cmccn" "$args_log"; then
        pass "$label 功能测试: curl 收到有效的 --connect-timeout、--max-time 及账号参数"
    else
        fail "$label 功能测试: curl 参数不完整" "$(tr '\n' ' ' < "$args_log")"
    fi

    trap - EXIT
    rm -rf "$tmpdir"
}

run_functional_test "sh/common/csu-net-auth.sh" "$REPO_ROOT/sh/common/csu-net-auth.sh"
run_functional_test "sh/openwrt/csu-net-auth.sh" "$REPO_ROOT/sh/openwrt/csu-net-auth.sh"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
