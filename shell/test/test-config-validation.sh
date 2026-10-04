#!/bin/sh
# 测试：配置校验
# 覆盖 shell/common/csu-autoauth.sh 与 openwrt/csu-autoauth.sh：
#   - TYPE 只接受 1/2/3/4，其它值必须报错退出（不再静默降级成"无后缀"）
#   - INTERVAL 必须是大于 0 的正整数
#   - USERNAME / PASSWORD 不能为空

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n  实际: %s\n' "$1" "$2" "$3"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

write_config() {
    cat > "$TMPDIR_ROOT/config.conf"
}

SHELL_SCRIPT="$REPO_ROOT/shell/common/csu-autoauth.sh"
OPENWRT_SCRIPT="$REPO_ROOT/openwrt/csu-autoauth.sh"

# shell 版本：整脚本直接运行，校验失败应退出码为 1 且 stderr 含关键字
check_shell_rejects() {
    label="$1"
    want_stderr="$2"

    set +e
    output=$(CONFIG_FILE="$TMPDIR_ROOT/config.conf" \
        DATA_DIR="$TMPDIR_ROOT" \
        LOG_FILE="$TMPDIR_ROOT/shell.log" \
        LOG_TO_STDOUT=0 \
        sh "$SHELL_SCRIPT" 2>&1)
    actual_rc=$?
    set -e

    if [ "$actual_rc" -ne 0 ] && printf '%s' "$output" | grep -qF "$want_stderr"; then
        pass "shell/common/csu-autoauth.sh [$label] 被拒绝：$(printf '%s' "$output" | head -n 1)"
    else
        fail "shell/common/csu-autoauth.sh [$label]" "非零退出码且包含 '$want_stderr'" "rc=$actual_rc output='$output'"
    fi
}

check_shell_accepts() {
    label="$1"

    set +e
    output=$(CONFIG_FILE="$TMPDIR_ROOT/config.conf" \
        DATA_DIR="$TMPDIR_ROOT" \
        LOG_FILE="$TMPDIR_ROOT/shell.log" \
        LOG_TO_STDOUT=0 \
        CSU_TESTING=1 \
        sh -c '. "$1"; validate_config && echo VALID' sh "$SHELL_SCRIPT" 2>&1)
    actual_rc=$?
    set -e

    if [ "$actual_rc" -eq 0 ] && printf '%s' "$output" | grep -q "VALID"; then
        pass "shell/common/csu-autoauth.sh [$label] 通过校验"
    else
        fail "shell/common/csu-autoauth.sh [$label]" "通过校验" "rc=$actual_rc output='$output'"
    fi
}

# openwrt 版本：注入配置后调用 validate_config，应返回非 0 并经 log() 写入日志
check_openwrt() {
    label="$1"
    want_rc="$2"
    want_log="$3"

    rm -f "$TMPDIR_ROOT/openwrt.log"
    set +e
    # 环境变量必须导出给子 sh；在 bash 中 `VAR=x . file` 的赋值不会保留到被 source 的脚本里
    LOG_DIR="$TMPDIR_ROOT" \
        LOG_FILE="$TMPDIR_ROOT/openwrt.log" \
        CSU_TESTING=1 \
        sh -c '. "$1"; . "$2"; validate_config' sh "$OPENWRT_SCRIPT" "$TMPDIR_ROOT/config.conf" >/dev/null 2>&1
    actual_rc=$?
    set -e

    log_ok=1
    if [ -n "$want_log" ]; then
        if [ ! -f "$TMPDIR_ROOT/openwrt.log" ] || ! grep -qF "$want_log" "$TMPDIR_ROOT/openwrt.log"; then
            log_ok=0
        fi
    fi

    if [ "$actual_rc" -eq "$want_rc" ] && [ "$log_ok" -eq 1 ]; then
        if [ -n "$want_log" ]; then
            pass "openwrt/csu-autoauth.sh [$label] 返回码 $actual_rc 且日志包含 '$want_log'"
        else
            pass "openwrt/csu-autoauth.sh [$label] 通过校验"
        fi
    else
        fail "openwrt/csu-autoauth.sh [$label]" "rc=$want_rc 且日志包含 '$want_log'" "rc=$actual_rc log='$(cat "$TMPDIR_ROOT/openwrt.log" 2>/dev/null || printf '%s' '(无日志)')'"
    fi
}

# ── 合法配置（先于失败用例写入） ──────────────────────────────────────────────

write_config <<'EOF'
USERNAME="20230001"
PASSWORD="ok"
TYPE="1"
INTERVAL="10"
EOF
check_shell_accepts "合法配置"
check_openwrt "合法配置" 0 ""

# ── TYPE 校验 ────────────────────────────────────────────────────────────────

for bad_type in "9" "cmcc" "" "5"; do
    write_config <<EOF
USERNAME="20230001"
PASSWORD="ok"
TYPE="$bad_type"
INTERVAL="10"
EOF
    check_shell_rejects "TYPE='$bad_type'" "TYPE must be one of 1, 2, 3, 4"
    check_openwrt "TYPE='$bad_type'" 1 "Invalid type"
done

# ── INTERVAL 校验 ────────────────────────────────────────────────────────────

for bad_interval in "0" "-1" "abc" "" "1.5"; do
    write_config <<EOF
USERNAME="20230001"
PASSWORD="ok"
TYPE="1"
INTERVAL="$bad_interval"
EOF
    check_shell_rejects "INTERVAL='$bad_interval'" "INTERVAL"
    check_openwrt "INTERVAL='$bad_interval'" 1 "Invalid interval"
done

# ── 凭据缺失 ─────────────────────────────────────────────────────────────────

write_config <<'EOF'
USERNAME=""
PASSWORD=""
TYPE="1"
INTERVAL="10"
EOF
check_shell_rejects "缺少凭据" "Missing USERNAME or PASSWORD"
check_openwrt "缺少凭据" 1 "Missing username or password"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
