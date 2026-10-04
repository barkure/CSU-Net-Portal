#!/bin/sh
# 测试：parse_login_response() 对 eportal 返回值的解析
# 覆盖 shell/common/csu-autoauth.sh 与 openwrt/csu-autoauth.sh 两个实现，
# 确保两者对 result/msg 的判定一致（成功输出 msg 且返回 0，失败输出错误信息且返回 1）。

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL: %s\n  期望: %s\n  实际: %s\n' "$1" "$2" "$3"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# 加载目标脚本（CSU_TESTING=1 跳过主循环），只调用 parse_login_response
run_parser() {
    script="$1"
    input="$2"

    CONFIG_FILE="$TMPDIR_ROOT/config.conf" \
    DATA_DIR="$TMPDIR_ROOT" \
    LOG_FILE="$TMPDIR_ROOT/test.log" \
    LOG_TO_STDOUT=0 \
    CSU_TESTING=1 \
    sh -c '. "$1"; parse_login_response "$2"' sh "$script" "$input"
}

check_case() {
    label="$1"
    script="$2"
    input="$3"
    want_rc="$4"
    want_msg="$5"
    script_name="${script#"$REPO_ROOT"/}"

    if output=$(run_parser "$script" "$input"); then
        actual_rc=0
    else
        actual_rc=$?
    fi

    if [ "$actual_rc" = "$want_rc" ] && [ "$output" = "$want_msg" ]; then
        pass "$script_name [$label] 返回码 $actual_rc 且消息为 '$output'"
    else
        fail "$script_name [$label]" "rc=$want_rc msg='$want_msg'" "rc=$actual_rc msg='$output'"
    fi
}

run_all_cases() {
    script="$1"

    check_case "result 为数字 1"        "$script" '{"result":1,"msg":"ok"}'              0 "ok"
    check_case "result 为字符串 \"1\""  "$script" '{"result":"1","msg":"ok"}'            0 "ok"
    check_case "字段间有空格"           "$script" '{ "result" : 1 , "msg" : "ok" }'      0 "ok"
    check_case "result=1 但无 msg"      "$script" '{"result":1}'                         0 "Login successful"
    check_case "跨行 JSON"              "$script" '{"result":1,
 "msg":"ok"}'                                                                          0 "ok"
    check_case "result=0 且带 msg"      "$script" '{"result":0,"msg":"密码错误"}'        1 "密码错误"
    check_case "result=0 且无 msg"      "$script" '{"result":0}'                         1 '{"result":0}'
    check_case "非 JSON 响应"           "$script" '<html>502 Bad Gateway</html>'         1 "<html>502 Bad Gateway</html>"
    check_case "空响应"                 "$script" ''                                     1 "empty response"
}

run_all_cases "$REPO_ROOT/shell/common/csu-autoauth.sh"
run_all_cases "$REPO_ROOT/openwrt/csu-autoauth.sh"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
