#!/bin/sh

set -eu

BASE_URL="${CSU_BASE_URL:-https://ssuu.us/csunet}"
PROMPT_INPUT_SET="${PROMPT_INPUT:-}"
PROMPT_INPUT="${PROMPT_INPUT:-/dev/stdin}"

USERNAME=""
PASSWORD=""
TYPE="1"

# 管道安装时从 /dev/tty 读交互输入；PROMPT_INPUT 已设则不覆盖（测试用）。
if [ -z "$PROMPT_INPUT_SET" ] && [ ! -t 0 ] && [ -r /dev/tty ]; then
    PROMPT_INPUT="/dev/tty"
fi

if ! command -v curl >/dev/null 2>&1; then
    printf '%s\n' "curl not found." >&2
    exit 1
fi

is_openwrt() {
    [ -f /etc/openwrt_release ]
}

detect_platform() {
    if is_openwrt; then
        printf '%s' "openwrt"
        return 0
    fi

    case "$(uname -s)" in
        Darwin) printf '%s' "darwin" ;;
        Linux) printf '%s' "linux" ;;
        *)
            printf '%s\n' "Unsupported OS: $(uname -s)" >&2
            exit 1
            ;;
    esac
}

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

collect_config() {
    USERNAME=$(prompt_with_default "学号" "${USERNAME:-}")
    PASSWORD=$(prompt_password "${PASSWORD:-}")
    TYPE=$(prompt_network_type "${TYPE:-1}")

    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        printf '%s\n' "学号和密码不能为空。" >&2
        exit 1
    fi
}

load_desktop_config() {
    HOME_DIR="${HOME:?HOME is not set}"
    BIN_DIR="$HOME_DIR/.local/bin"
    CONFIG_DIR="$HOME_DIR/.config/csu-net-auth"
    DATA_DIR="$HOME_DIR/.local/share/csu-net-auth"
    CONFIG_DST="$CONFIG_DIR/config.conf"
    SCRIPT_DST="$BIN_DIR/csu-net-auth"
    LOG_FILE="$DATA_DIR/csu-net-auth.log"

    if [ -f "$CONFIG_DST" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_DST"
    fi
}

load_openwrt_config() {
    if command -v uci >/dev/null 2>&1; then
        USERNAME=$(uci -q get csu-net-auth.main.username 2>/dev/null || true)
        PASSWORD=$(uci -q get csu-net-auth.main.password 2>/dev/null || true)
        TYPE=$(uci -q get csu-net-auth.main.type 2>/dev/null || printf '%s' "1")
        USERNAME="${USERNAME:-}"
        PASSWORD="${PASSWORD:-}"
        TYPE="${TYPE:-1}"
    fi
}

install_desktop_files() {
    mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR"
    curl -fsSL "$BASE_URL/sh/common/csu-net-auth.sh" -o "$SCRIPT_DST"
    chmod 755 "$SCRIPT_DST"

    umask 077
    cat > "$CONFIG_DST" <<EOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
TYPE="$TYPE"
EOF
    touch "$LOG_FILE"
}

install_linux() {
    SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"
    SERVICE_DST="$SYSTEMD_USER_DIR/csu-net-auth.service"

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
ExecStart=%h/.local/bin/csu-net-auth
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now csu-net-auth.service

    printf '%s\n' "Installed service: $SERVICE_DST"
}

install_macos() {
    LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
    PLIST_DST="$LAUNCH_AGENTS_DIR/com.barkure.csu-net-auth.plist"

    mkdir -p "$LAUNCH_AGENTS_DIR"
    cat > "$PLIST_DST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.barkure.csu-net-auth</string>

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

install_openwrt() {
    if ! command -v uci >/dev/null 2>&1; then
        printf '%s\n' "uci not found. OpenWrt install requires uci." >&2
        exit 1
    fi

    mkdir -p /usr/bin /etc/init.d /etc/config

    curl -fsSL "$BASE_URL/sh/openwrt/csu-net-auth.sh" -o /usr/bin/csu-net-auth.sh
    curl -fsSL "$BASE_URL/sh/openwrt/csu-net-auth.init" -o /etc/init.d/csu-net-auth

    if [ ! -f /etc/config/csu-net-auth ]; then
        curl -fsSL "$BASE_URL/sh/openwrt/csu-net-auth.config" -o /etc/config/csu-net-auth
    fi

    chmod 755 /usr/bin/csu-net-auth.sh /etc/init.d/csu-net-auth

    uci set csu-net-auth.main.username="$USERNAME"
    uci set csu-net-auth.main.password="$PASSWORD"
    uci set csu-net-auth.main.type="$TYPE"
    uci commit csu-net-auth

    /etc/init.d/csu-net-auth enable
    if /etc/init.d/csu-net-auth running >/dev/null 2>&1; then
        /etc/init.d/csu-net-auth restart
    else
        /etc/init.d/csu-net-auth start
    fi

    printf '%s\n' "Installed script: /usr/bin/csu-net-auth.sh"
    printf '%s\n' "Installed init script: /etc/init.d/csu-net-auth"
    printf '%s\n' "Installed config: /etc/config/csu-net-auth"
    printf '%s\n' "Log file: /var/log/csu-net-auth.log"
}

PLATFORM=$(detect_platform)

case "$PLATFORM" in
    openwrt)
        load_openwrt_config
        collect_config
        install_openwrt
        ;;
    linux)
        load_desktop_config
        collect_config
        install_desktop_files
        install_linux
        printf '%s\n' "Installed script: $SCRIPT_DST"
        printf '%s\n' "Installed config: $CONFIG_DST"
        printf '%s\n' "Log file: $LOG_FILE"
        ;;
    darwin)
        load_desktop_config
        collect_config
        install_desktop_files
        install_macos
        printf '%s\n' "Installed script: $SCRIPT_DST"
        printf '%s\n' "Installed config: $CONFIG_DST"
        printf '%s\n' "Log file: $LOG_FILE"
        ;;
esac
