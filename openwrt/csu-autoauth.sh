#!/bin/sh

# === User configuration ===
USERNAME="YOUR_STUDENT_NUMBER" # Your student number, e.g., 812345678
PASSWORD="YOUR_PASSWORD" # Your password
TYPE="1"  # 1=China Mobile, 2=China Unicom, 3=China Telecom, 4=Campus Network
INTERVAL=10  # Interval between checks (in seconds)

# === Log location ===
LOG_DIR="${LOG_DIR:-/tmp/log}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/csu-autoauth.log}"

# === Network type mapping ===
case "$TYPE" in
    "1") NET_SUFFIX="cmccn" ;;
    "2") NET_SUFFIX="unicomn" ;;
    "3") NET_SUFFIX="telecomn" ;;
    "4") NET_SUFFIX="" ;;
    *)   NET_SUFFIX="" ;;
esac

# === Time helper ===
get_time() {
    date '+%Y-%m-%d %H:%M:%S'
}

# === Log initialization ===
init_log_file() {
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
}

# === Logging helper ===
log() {
    message="[$(get_time)] $1"
    echo "$message"
    printf '%s\n' "$message" >> "$LOG_FILE"
}

# === Check if network is online ===
is_online() {
    curl -s --max-time 5 http://captive.apple.com | grep -q "Success"
}

# === Login authentication ===
login() {
    if [ -n "$NET_SUFFIX" ]; then
        USER_ACCOUNT="${USERNAME}@${NET_SUFFIX}"
    else
        USER_ACCOUNT="$USERNAME"
    fi

    URL="https://portal.csu.edu.cn:802/eportal/portal/login"
    log "Authenticating as: $USER_ACCOUNT"
    response=$(curl -k -s -G "$URL" \
        -d "user_account=$USER_ACCOUNT" \
        -d "user_password=$PASSWORD")
    log "Login response: $response"
}

# === Main loop ===
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
