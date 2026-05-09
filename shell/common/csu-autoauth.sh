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
    "1") NET_SUFFIX="cmccn" ;;
    "2") NET_SUFFIX="unicomn" ;;
    "3") NET_SUFFIX="telecomn" ;;
    "4") NET_SUFFIX="" ;;
    *)   NET_SUFFIX="" ;;
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

login() {
    if [ -n "$NET_SUFFIX" ]; then
        USER_ACCOUNT="${USERNAME}@${NET_SUFFIX}"
    else
        USER_ACCOUNT="$USERNAME"
    fi

    URL="https://10.1.1.1:802/eportal/portal/login"
    log "Authenticating as: $USER_ACCOUNT"
    response=$(curl -k -fsS -G "$URL" \
        -d "user_account=$USER_ACCOUNT" \
        -d "user_password=$PASSWORD" 2>&1 || true)
    log "Login response: $response"
}

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
