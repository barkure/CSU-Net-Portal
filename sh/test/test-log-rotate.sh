#!/bin/sh
# 日志超限轮转到 .1。

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n  实际: %s\n' "$1" "$2" "$3"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

run_case() {
    label="$1"
    script="$2"

    tmpdir=$(mktemp -d)

    log_file="$tmpdir/csu-net-auth.log"
    # 超过阈值：200 字节
    dd if=/dev/zero of="$log_file" bs=200 count=1 2>/dev/null

    CONFIG_FILE="$tmpdir/config.conf" \
    DATA_DIR="$tmpdir" \
    LOG_FILE="$log_file" \
    LOG_DIR="$tmpdir" \
    LOG_TO_STDOUT=0 \
    LOG_MAX_BYTES=100 \
    CSU_TESTING=1 \
    sh -c '. "$1"; init_log_file; log "rotated"' sh "$script"

    if [ -f "${log_file}.1" ] && [ -f "$log_file" ] && grep -q 'rotated' "$log_file"; then
        old_size=$(wc -c < "${log_file}.1" | tr -d '[:space:]')
        if [ "$old_size" -eq 200 ]; then
            pass "$label 轮转到 .1 并写入新日志"
        else
            fail "$label .1 大小" "200" "$old_size"
        fi
    else
        fail "$label 轮转结果" ".1 存在且新日志含 rotated" "$(ls -la "$tmpdir")"
    fi

    rm -rf "$tmpdir"
}

run_case "sh/common/csu-net-auth.sh" "$REPO_ROOT/sh/common/csu-net-auth.sh"
run_case "sh/openwrt/csu-net-auth.sh" "$REPO_ROOT/sh/openwrt/csu-net-auth.sh"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
