#!/bin/sh

HOME_DIR="${HOME:?HOME is not set}"
BIN_DIR="$HOME_DIR/.local/bin"
CONFIG_DIR="$HOME_DIR/.config/csu-autoauth"
DATA_DIR="$HOME_DIR/.local/share/csu-autoauth"
CONFIG_DST="$CONFIG_DIR/config.conf"
SCRIPT_DST="$BIN_DIR/csu-autoauth"
LOG_FILE="$DATA_DIR/csu-autoauth.log"
PROMPT_INPUT="/dev/stdin"

USERNAME=""
PASSWORD=""
TYPE="1"
INTERVAL="10"

if [ ! -t 0 ] && [ -r /dev/tty ]; then
    PROMPT_INPUT="/dev/tty"
fi

load_existing_config() {
    if [ -f "$CONFIG_DST" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_DST"
    fi
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
    load_existing_config

    USERNAME=$(prompt_with_default "学号" "${USERNAME:-}")
    PASSWORD=$(prompt_password "${PASSWORD:-}")
    TYPE=$(prompt_network_type "${TYPE:-1}")
    INTERVAL=$(prompt_interval "${INTERVAL:-10}")

    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        printf '%s\n' "学号和密码不能为空。" >&2
        exit 1
    fi
}

write_config() {
    mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR"
    install -m 755 "$1" "$SCRIPT_DST"

    umask 077
    cat > "$CONFIG_DST" <<EOF
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
TYPE="$TYPE"
INTERVAL="$INTERVAL"
EOF
    touch "$LOG_FILE"
}
