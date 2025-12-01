#!/bin/sh

# === User configuration ===
username="812345678"
password="abcdefg"
type="1"  # 1=China Mobile, 2=China Unicom, 3=China Telecom, 4=Campus Network
interval=10  # Interval between checks (in seconds)

# === Log file ===
log_file="$HOME/Scripts/csu-autoauth.log"

# === Network type mapping ===
case "$type" in
    "1") net_suffix="cmccn" ;;
    "2") net_suffix="unicomn" ;;
    "3") net_suffix="telecomn" ;;
    "4") net_suffix="" ;;
    *)   net_suffix="" ;;
esac

# === Time helper ===
get_time() {
    date '+%Y-%m-%d %H:%M:%S'
}

# === Logging helper ===
log() {
    echo "[$(get_time)] $1" | tee -a "$log_file"
}

# === Check if network is online ===
is_online() {
    curl -s --max-time 5 http://captive.apple.com | grep -q "Success"
}

# === Login authentication ===
login() {
    user_account="${username}@${net_suffix}"
    url="https://portal.csu.edu.cn:802/eportal/portal/login"
    log "Authenticating as: $user_account"
    response=$(curl -k -s -G "$url" \
        -d "user_account=$user_account" \
        -d "user_password=$password")
    log "Login response: $response"
}

# === Main loop ===
log "Start monitoring network status (every ${interval}s)..."
while true; do
    if is_online; then
        log "Network up"
    else
        log "Network down, triggering authentication..."
        login
    fi
    sleep "$interval"
done
