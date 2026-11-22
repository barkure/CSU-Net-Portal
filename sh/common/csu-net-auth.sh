#!/bin/sh

set -eu

HOME_DIR="${HOME:?HOME is not set}"
CONFIG_FILE="${CONFIG_FILE:-$HOME_DIR/.config/csu-net-auth/config.conf}"
DATA_DIR="${DATA_DIR:-$HOME_DIR/.local/share/csu-net-auth}"
LOG_FILE="${LOG_FILE:-$DATA_DIR/csu-net-auth.log}"
LOG_TO_STDOUT="${LOG_TO_STDOUT:-1}"
LOG_MAX_BYTES="${LOG_MAX_BYTES:-1048576}"

USERNAME=""
PASSWORD=""
TYPE="1"

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
    message="[$(timestamp)] $1"
    if [ "$LOG_TO_STDOUT" = "1" ]; then
        printf '%s\n' "$message"
    fi
    rotate_log_if_needed
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
    validate_config
    init_log_file
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
