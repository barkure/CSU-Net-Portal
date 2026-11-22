#!/bin/sh

# 单元测试环境可能没有 /lib/functions.sh。
if [ -r /lib/functions.sh ]; then
    . /lib/functions.sh
fi

CONFIG_SECTION="${CONFIG_SECTION:-main}"

USERNAME=""
PASSWORD=""
TYPE=""

LOG_DIR="${LOG_DIR:-/var/log}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/csu-net-auth.log}"
LOG_MAX_BYTES="${LOG_MAX_BYTES:-1048576}"

get_time() {
    date '+%Y-%m-%d %H:%M:%S'
}

init_log_file() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
}

rotate_log_if_needed() {
    [ -f "$LOG_FILE" ] || return 0

    size=$(wc -c < "$LOG_FILE" 2>/dev/null || printf '0')
    size=$(printf '%s' "$size" | tr -d '[:space:]')
    case "$size" in
        ''|*[!0-9]*) return 0 ;;
    esac

    if [ "$size" -ge "$LOG_MAX_BYTES" ]; then
        mv -f "$LOG_FILE" "${LOG_FILE}.1"
        touch "$LOG_FILE"
    fi
}

log() {
    message="[$(get_time)] $1"
    printf '%s\n' "$message"
    rotate_log_if_needed
    printf '%s\n' "$message" >> "$LOG_FILE"
}

load_config() {
    config_load csu-net-auth || return 1
    config_get USERNAME "$CONFIG_SECTION" username
    config_get PASSWORD "$CONFIG_SECTION" password
    config_get TYPE "$CONFIG_SECTION" type "1"

    resolve_net_suffix
}

resolve_net_suffix() {
    case "$TYPE" in
        1) NET_SUFFIX="cmccn" ;;
        2) NET_SUFFIX="unicomn" ;;
        3) NET_SUFFIX="telecomn" ;;
        4) NET_SUFFIX="" ;;
        *) NET_SUFFIX="" ;;
    esac
}

validate_config() {
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        log "Missing username or password in /etc/config/csu-net-auth"
        return 1
    fi

    case "$TYPE" in
        1|2|3|4) ;;
        *)
            log "Invalid type '$TYPE', expected one of 1, 2, 3, 4"
            return 1
            ;;
    esac
}

is_online() {
    curl -fsS --max-time 5 http://captive.apple.com/hotspot-detect.html 2>/dev/null | grep -q "Success"
}

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
    response=$(curl -k -fsS --connect-timeout 5 --max-time 10 -G "$URL" \
        --data-urlencode "user_account=$USER_ACCOUNT" \
        --data-urlencode "user_password=$PASSWORD" 2>&1 || true)

    if login_message=$(parse_login_response "$response"); then
        log "Login successful: $login_message"
    else
        log "Login failed: $login_message"
    fi
}

if [ "${CSU_TESTING:-0}" = "0" ]; then
    init_log_file
    load_config || {
        log "Failed to load UCI config: /etc/config/csu-net-auth"
        exit 1
    }
    validate_config || exit 1
    log "Start monitoring network status (every 10s)..."

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
        sleep 10
    done
fi
