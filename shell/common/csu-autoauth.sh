#!/bin/sh

set -eu

HOME_DIR="${HOME:?HOME is not set}"
CONFIG_FILE="${CONFIG_FILE:-$HOME_DIR/.config/csu-autoauth/config.conf}"
DATA_DIR="${DATA_DIR:-$HOME_DIR/.local/share/csu-autoauth}"
LOG_FILE="${LOG_FILE:-$DATA_DIR/csu-autoauth.log}"
LOG_TO_STDOUT="${LOG_TO_STDOUT:-1}"

USERNAME=""
PASSWORD=""
TYPE="1"
INTERVAL="10"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

case "${TYPE:-}" in
    1) NET_SUFFIX="cmccn" ;;
    2) NET_SUFFIX="unicomn" ;;
    3) NET_SUFFIX="telecomn" ;;
    4) NET_SUFFIX="" ;;
    *) NET_SUFFIX="" ;;
esac

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

init_log_file() {
    mkdir -p "$DATA_DIR"
    touch "$LOG_FILE"
}

log() {
    message="[$(timestamp)] $1"
    if [ "$LOG_TO_STDOUT" = "1" ]; then
        printf '%s\n' "$message"
    fi
    printf '%s\n' "$message" >> "$LOG_FILE"
}

validate_config() {
    if [ -z "${USERNAME:-}" ] || [ -z "${PASSWORD:-}" ]; then
        printf '%s\n' "Missing USERNAME or PASSWORD in $CONFIG_FILE" >&2
        exit 1
    fi

    case "${TYPE:-}" in
        1|2|3|4) ;;
        *)
            printf '%s\n' "TYPE must be one of 1, 2, 3, 4 in $CONFIG_FILE (got '${TYPE:-}')" >&2
            exit 1
            ;;
    esac

    case "${INTERVAL:-}" in
        ''|*[!0-9]*)
            printf '%s\n' "INTERVAL must be a positive integer in $CONFIG_FILE" >&2
            exit 1
            ;;
    esac

    if [ "$INTERVAL" -le 0 ]; then
        printf '%s\n' "INTERVAL must be greater than 0 in $CONFIG_FILE" >&2
        exit 1
    fi
}

is_online() {
    curl -fsS --max-time 5 http://captive.apple.com/hotspot-detect.html 2>/dev/null | grep -q "Success"
}

# 解析 eportal 登录响应：成功时输出服务端 msg 并以 0 退出，否则输出错误信息并返回 1。
# 非 JSON 响应（例如网关 502 页面）视为失败，原样作为错误信息。
parse_login_response() {
    response_text=$(printf '%s' "$1" | tr -d '\r\n')
    result_value=$(printf '%s' "$response_text" | sed -n 's/.*"result"[[:space:]]*:[[:space:]]*"\{0,1\}\([0-9][0-9]*\)"\{0,1\}.*/\1/p')
    message=$(printf '%s' "$response_text" | sed -n 's/.*"msg"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    if [ "$result_value" = "1" ]; then
        printf '%s' "${message:-Login successful}"
        return 0
    fi

    printf '%s' "${message:-${response_text:-empty response}}"
    return 1
}

login() {
    if [ -n "$NET_SUFFIX" ]; then
        USER_ACCOUNT="${USERNAME}@${NET_SUFFIX}"
    else
        USER_ACCOUNT="$USERNAME"
    fi

    URL="https://10.1.1.1:802/eportal/portal/login"
    log "Authenticating as: $USER_ACCOUNT"
    response=$(curl -k -fsS -G "$URL" \
        --data-urlencode "user_account=$USER_ACCOUNT" \
        --data-urlencode "user_password=$PASSWORD" 2>&1 || true)

    if login_message=$(parse_login_response "$response"); then
        log "Login successful: $login_message"
    else
        log "Login failed: $login_message"
    fi
}

if [ "${CSU_TESTING:-0}" = "0" ]; then
    validate_config
    init_log_file
    log "Start monitoring network status (every ${INTERVAL}s)..."

    LAST_STATUS=""

    while true; do
        if is_online; then
            CURRENT_STATUS="up"
            if [ "$LAST_STATUS" != "$CURRENT_STATUS" ]; then
                log "Network up"
                LAST_STATUS="$CURRENT_STATUS"
            fi
        else
            CURRENT_STATUS="down"
            if [ "$LAST_STATUS" != "$CURRENT_STATUS" ]; then
                log "Network down"
                LAST_STATUS="$CURRENT_STATUS"
            fi
            log "Triggering authentication..."
            login
        fi
        sleep "$INTERVAL"
    done
fi
