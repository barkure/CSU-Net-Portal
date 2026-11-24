#!/bin/sh
# 安装来源与 OpenWrt 路径静态检查。

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n  实际: %s\n' "$1" "$2" "$3"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

make_stubs() {
    stub_bin="$1"
    mkdir -p "$stub_bin"

    cat > "$stub_bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$CURL_LOG"
output=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) output="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if [ -n "$output" ]; then
    printf '#!/bin/sh\n# stub\n' > "$output"
fi
exit 0
EOF

    printf '#!/bin/sh\nprintf "%%s\\n" "$FAKE_UNAME"\n' > "$stub_bin/uname"
    printf '#!/bin/sh\nexit 0\n' > "$stub_bin/systemctl"
    printf '#!/bin/sh\nexit 0\n' > "$stub_bin/launchctl"
    printf '#!/bin/sh\nexit 0\n' > "$stub_bin/pkill"
    chmod +x "$stub_bin"/*
}

# 答案走管道；普通文件每次 read 会重复首行。
ANSWERS='20230001
secret
1
'

run_shell_installer() {
    label="$1"
    shift

    case_dir="$TMPDIR_ROOT/shell-$label"
    rm -rf "$case_dir"
    mkdir -p "$case_dir/home" "$case_dir/bin"
    make_stubs "$case_dir/bin"
    : > "$case_dir/curl.log"

    printf '%b' "$ANSWERS" | env "$@" \
        HOME="$case_dir/home" \
        CURL_LOG="$case_dir/curl.log" \
        FAKE_UNAME="Darwin" \
        PROMPT_INPUT="/dev/stdin" \
        PATH="$case_dir/bin:$PATH" \
        sh "$REPO_ROOT/sh/install.sh" > "$case_dir/out.log" 2>&1 || {
        fail "sh/install.sh [$label]" "安装成功退出" "$(tail -n 3 "$case_dir/out.log")"
        return
    }

    printf '%s' "$(head -n 1 "$case_dir/curl.log")"
}

check_shell_source() {
    label="$1"
    want_url="$2"
    shift 2

    actual_url=$(run_shell_installer "$label" "$@")
    script_url=$(printf '%s' "$actual_url" | tr ' ' '\n' | grep 'csu-net-auth.sh' | head -n 1)

    if [ "$script_url" = "$want_url" ]; then
        pass "sh/install.sh [$label] 从 $script_url 拉取脚本"
    else
        fail "sh/install.sh [$label]" "$want_url" "$script_url"
    fi
}

check_shell_installed_files() {
    label="$1"
    case_dir="$TMPDIR_ROOT/shell-$label"

    if [ -f "$case_dir/home/.config/csu-net-auth/config.conf" ] &&
       grep -q 'USERNAME="20230001"' "$case_dir/home/.config/csu-net-auth/config.conf" &&
       [ -f "$case_dir/home/.local/share/csu-net-auth/csu-net-auth.log" ] &&
       [ -f "$case_dir/home/Library/LaunchAgents/com.barkure.csu-net-auth.plist" ]; then
        pass "sh/install.sh [$label] 写入脚本/配置/日志/launchd 文件"
    else
        fail "sh/install.sh [$label] 文件落地" "config.conf + log + plist" "$(ls -R "$case_dir/home" 2>/dev/null | tr '\n' ' ')"
    fi
}

DEFAULT_BASE="https://ssuu.us/csunet"

check_shell_source "默认来源" "$DEFAULT_BASE/sh/common/csu-net-auth.sh"
check_shell_installed_files "默认来源"

check_shell_source "自定义 BASE_URL" "https://example.test/csunet/sh/common/csu-net-auth.sh" \
    CSU_BASE_URL="https://example.test/csunet"
check_shell_installed_files "自定义 BASE_URL"


check_file_contains() {
    label="$1"
    file="$2"
    pattern="$3"

    if grep -qF "$pattern" "$file"; then
        pass "$label"
    else
        fail "$label" "包含 '$pattern'" "$(grep -n 'BASE_URL\|openwrt\|LOG_DIR\|/var/log' "$file" | head -n 3 | tr '\n' ' ')"
    fi
}

check_file_absent() {
    label="$1"
    file="$2"
    pattern="$3"

    if grep -qF "$pattern" "$file"; then
        fail "$label" "不再包含 '$pattern'" "$(grep -nF "$pattern" "$file" | head -n 2 | tr '\n' ' ')"
    else
        pass "$label"
    fi
}

INSTALL="$REPO_ROOT/sh/install.sh"
UNINSTALL="$REPO_ROOT/sh/uninstall.sh"
OPENWRT_SCRIPT="$REPO_ROOT/sh/openwrt/csu-net-auth.sh"

check_file_contains "sh/install.sh 默认 BASE_URL 为 ssuu.us" "$INSTALL" 'BASE_URL="${CSU_BASE_URL:-https://ssuu.us/csunet}"'
check_file_contains "sh/install.sh 从 BASE_URL 拉取 openwrt 脚本" "$INSTALL" 'curl -fsSL "$BASE_URL/sh/openwrt/csu-net-auth.sh" -o /usr/bin/csu-net-auth.sh'
check_file_contains "sh/install.sh 交互写入 UCI" "$INSTALL" 'uci set csu-net-auth.main.username="$USERNAME"'

check_file_contains "openwrt 脚本日志目录为 /var/log" "$OPENWRT_SCRIPT" 'LOG_DIR="${LOG_DIR:-/var/log}"'
check_file_absent "openwrt 脚本不再写 /tmp/log" "$OPENWRT_SCRIPT" '/tmp/log'
check_file_absent "sh/install.sh 不再提示 /tmp/log" "$INSTALL" '/tmp/log'
check_file_absent "sh/uninstall.sh 不再清理 /tmp/log" "$UNINSTALL" '/tmp/log'
check_file_contains "sh/uninstall.sh 清理 /var/log 日志" "$UNINSTALL" 'rm -f /var/log/csu-net-auth.log'
check_file_contains "sh/uninstall.sh 探测 OpenWrt" "$UNINSTALL" '[ -f /etc/openwrt_release ]'

if [ -d "$REPO_ROOT/openwrt" ]; then
    fail "顶层 openwrt/ 已合并进 sh/openwrt" "目录不存在" "目录仍存在"
else
    pass "顶层 openwrt/ 已合并进 sh/openwrt"
fi

if [ -d "$REPO_ROOT/sh/openwrt/package" ]; then
    fail "openwrt/package 副本已删除" "目录不存在" "目录仍存在（与 openwrt/* 存在漂移风险）"
else
    pass "openwrt/package 副本已删除"
fi

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
