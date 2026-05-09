#!/bin/sh

set -eu

REPO_RAW_URL="${REPO_RAW_URL:-https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main}"
HOME_DIR="${HOME:?HOME is not set}"
BIN_DIR="$HOME_DIR/.local/bin"
CONFIG_DIR="$HOME_DIR/.config/csu-autoauth"
DATA_DIR="$HOME_DIR/.local/share/csu-autoauth"
CONFIG_DST="$CONFIG_DIR/config.conf"
SCRIPT_DST="$BIN_DIR/csu-autoauth"
LOG_FILE="$DATA_DIR/csu-autoauth.log"
OS_NAME="$(uname -s)"
PROMPT_INPUT="/dev/stdin"

USERNAME=""
PASSWORD=""
TYPE="1"
INTERVAL="10"

if [ ! -t 0 ] && [ -r /dev/tty ]; then
    PROMPT_INPUT="/dev/tty"
fi

if ! command -v curl >/dev/null 2>&1; then
    printf '%s\n' "curl not found." >&2
    exit 1
fi

if [ -f "$CONFIG_DST" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_DST"
fi

prompt_with_default() {
    prompt="$1"
    default_value="$2"

    if [ -n "$default_value" ]; then
        printf '%s [%s]: ' "$prompt" "$default_value" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi

    IFS= read -r input_value < "$PROMPT_INPUT" || input_value=""

    if [ -n "$input_value" ]; then
        printf '%s' "$input_value"
    else
        printf '%s' "$default_value"
    fi
}

prompt_password() {
    current_password="$1"
    if [ -n "$current_password" ]; then
        printf '%s [%s]: ' "密码" "$current_password" >&2
    else
        printf '%s: ' "密码" >&2
    fi
    IFS= read -r input_password < "$PROMPT_INPUT" || input_password=""

    if [ -n "$input_password" ]; then
        printf '%s' "$input_password"
    else
        printf '%s' "$current_password"
    fi
}

prompt_network_type() {
    current_type="$1"

    while true; do
        printf '%s\n' "网络类型:" >&2
        printf '%s\n' "  1) 中国移动" >&2
        printf '%s\n' "  2) 中国联通" >&2
        printf '%s\n' "  3) 中国电信" >&2
        printf '%s\n' "  4) 校园网" >&2

        selected_type=$(prompt_with_default "请选择" "$current_type")

        case "$selected_type" in
            1|2|3|4)
                printf '%s' "$selected_type"
                return 0
                ;;
        esac

        printf '%s\n' "无效选项，请输入 1、2、3 或 4。" >&2
    done
}

prompt_interval() {
    current_interval="$1"

    while true; do
        selected_interval=$(prompt_with_default "检测间隔（秒）" "$current_interval")
        case "$selected_interval" in
            ''|*[!0-9]*)
                printf '%s\n' "时间间隔必须是正整数。" >&2
                ;;
            *)
                if [ "$selected_interval" -gt 0 ]; then
                    printf '%s' "$selected_interval"
                    return 0
                fi
                printf '%s\n' "时间间隔必须大于 0。" >&2
                ;;
        esac
    done
}

collect_config() {
    USERNAME=$(prompt_with_default "学号" "${USERNAME:-}")
    PASSWORD=$(prompt_password "${PASSWORD:-}")
    TYPE=$(prompt_network_type "${TYPE:-1}")
    INTERVAL=$(prompt_interval "${INTERVAL:-10}")

    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        printf '%s\n' "学号和密码不能为空。" >&2
        exit 1
    fi
}

install_common_files() {
    mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR"
    curl -fsSL "$REPO_RAW_URL/shell/common/csu-autoauth.sh" -o "$SCRIPT_DST"
    chmod 755 "$SCRIPT_DST"

    umask 077
    cat > "$CONFIG_DST" <<EOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
TYPE="$TYPE"
INTERVAL="$INTERVAL"
EOF
    touch "$LOG_FILE"
}

install_linux() {
    SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"
    SERVICE_DST="$SYSTEMD_USER_DIR/csu-autoauth.service"

    if ! command -v systemctl >/dev/null 2>&1; then
        printf '%s\n' "systemctl not found. This installer requires systemd user services." >&2
        exit 1
    fi

    mkdir -p "$SYSTEMD_USER_DIR"
    cat > "$SERVICE_DST" <<EOF
[Unit]
Description=CSU Network Auto Auth
Documentation=https://github.com/barkure/CSU-Net-Portal
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/csu-autoauth
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now csu-autoauth.service

    printf '%s\n' "Installed service: $SERVICE_DST"
}

install_macos() {
    LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
    PLIST_DST="$LAUNCH_AGENTS_DIR/com.barkure.csu-autoauth.plist"

    mkdir -p "$LAUNCH_AGENTS_DIR"
    cat > "$PLIST_DST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.barkure.csu-autoauth</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>LOG_TO_STDOUT</key>
        <string>0</string>
    </dict>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-lc</string>
        <string>exec "$SCRIPT_DST"</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>

    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
</dict>
</plist>
EOF

    launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
    launchctl load "$PLIST_DST"

    printf '%s\n' "Installed plist: $PLIST_DST"
}

collect_config
install_common_files

case "$OS_NAME" in
    Linux)
        install_linux
        ;;
    Darwin)
        install_macos
        ;;
    *)
        printf '%s\n' "Unsupported OS: $OS_NAME" >&2
        exit 1
        ;;
esac

printf '%s\n' "Installed script: $SCRIPT_DST"
printf '%s\n' "Installed config: $CONFIG_DST"
printf '%s\n' "Log file: $LOG_FILE"
