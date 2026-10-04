#!/bin/sh
# 测试：安装脚本的默认下载来源
#   - shell/install.sh：功能测试（stub curl/launchctl/systemctl，HOME 指向临时目录）
#   - openwrt/install.sh：静态检查（脚本写死绝对路径 /usr/bin、/etc/config，无法在隔离环境执行）
# 同时回归检查 OpenWrt 日志路径已从 /tmp/log 迁到 /var/log。

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n  实际: %s\n' "$1" "$2" "$3"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# ── 通用 stub ────────────────────────────────────────────────────────────────

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

# 提示符按顺序从管道读取（普通文件会因每次 read 重新定位而重复读到第一行）
ANSWERS='20230001
secret
1
10
'

run_shell_installer() {
    label="$1"
    shift

    case_dir="$TMPDIR_ROOT/shell-$label"
    rm -rf "$case_dir"
    mkdir -p "$case_dir/home" "$case_dir/bin"
    make_stubs "$case_dir/bin"
    : > "$case_dir/curl.log"

    # `VAR=value` 经 "$@" 展开后不再是赋值前缀（会被当作命令名），因此用 env 注入
    printf '%b' "$ANSWERS" | env "$@" \
        HOME="$case_dir/home" \
        CURL_LOG="$case_dir/curl.log" \
        FAKE_UNAME="Darwin" \
        PROMPT_INPUT="/dev/stdin" \
        PATH="$case_dir/bin:$PATH" \
        sh "$REPO_ROOT/shell/install.sh" > "$case_dir/out.log" 2>&1 || {
        fail "shell/install.sh [$label]" "安装成功退出" "$(tail -n 3 "$case_dir/out.log")"
        return
    }

    printf '%s' "$(head -n 1 "$case_dir/curl.log")"
}

check_shell_source() {
    label="$1"
    want_url="$2"
    shift 2

    actual_url=$(run_shell_installer "$label" "$@")
    script_url=$(printf '%s' "$actual_url" | tr ' ' '\n' | grep 'csu-autoauth.sh' | head -n 1)

    if [ "$script_url" = "$want_url" ]; then
        pass "shell/install.sh [$label] 从 $script_url 拉取脚本"
    else
        fail "shell/install.sh [$label]" "$want_url" "$script_url"
    fi
}

check_shell_installed_files() {
    label="$1"
    case_dir="$TMPDIR_ROOT/shell-$label"

    if [ -f "$case_dir/home/.config/csu-autoauth/config.conf" ] &&
       grep -q 'USERNAME="20230001"' "$case_dir/home/.config/csu-autoauth/config.conf" &&
       [ -f "$case_dir/home/.local/share/csu-autoauth/csu-autoauth.log" ] &&
       [ -f "$case_dir/home/Library/LaunchAgents/com.barkure.csu-autoauth.plist" ]; then
        pass "shell/install.sh [$label] 写入脚本/配置/日志/launchd 文件"
    else
        fail "shell/install.sh [$label] 文件落地" "config.conf + log + plist" "$(ls -R "$case_dir/home" 2>/dev/null | tr '\n' ' ')"
    fi
}

DEFAULT_BASE="https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main"

check_shell_source "默认来源" "$DEFAULT_BASE/shell/common/csu-autoauth.sh"
check_shell_installed_files "默认来源"


# ── openwrt：静态检查 ─────────────────────────────────────────────────────────

check_file_contains() {
    label="$1"
    file="$2"
    pattern="$3"

    if grep -qF "$pattern" "$file"; then
        pass "$label"
    else
        fail "$label" "包含 '$pattern'" "$(grep -n 'download_file\|LOG_DIR' "$file" | head -n 3 | tr '\n' ' ')"
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

OPENWRT_INSTALL="$REPO_ROOT/openwrt/install.sh"
OPENWRT_SCRIPT="$REPO_ROOT/openwrt/csu-autoauth.sh"
OPENWRT_UNINSTALL="$REPO_ROOT/openwrt/uninstall.sh"

check_file_contains "openwrt/install.sh 默认从 main 下载" "$OPENWRT_INSTALL" 'download_file "/usr/bin/csu-autoauth.sh" "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/csu-autoauth.sh"'

check_file_contains "openwrt 脚本日志目录为 /var/log" "$OPENWRT_SCRIPT" 'LOG_DIR="${LOG_DIR:-/var/log}"'
check_file_absent "openwrt 脚本不再写 /tmp/log" "$OPENWRT_SCRIPT" '/tmp/log'
check_file_absent "openwrt/install.sh 不再提示 /tmp/log" "$OPENWRT_INSTALL" '/tmp/log'
check_file_absent "openwrt/uninstall.sh 不再清理 /tmp/log" "$OPENWRT_UNINSTALL" '/tmp/log'
check_file_contains "openwrt/uninstall.sh 清理 /var/log 日志" "$OPENWRT_UNINSTALL" 'rm -f /var/log/csu-autoauth.log'

# ── 已删除的 openwrt/package 副本不应复活 ─────────────────────────────────────

if [ -d "$REPO_ROOT/openwrt/package" ]; then
    fail "openwrt/package 副本已删除" "目录不存在" "目录仍存在（与 openwrt/* 存在漂移风险）"
else
    pass "openwrt/package 副本已删除"
fi

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
