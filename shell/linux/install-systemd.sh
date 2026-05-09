#!/bin/sh

set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$BASE_DIR/../common/install-common.sh"

SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"
SERVICE_DST="$SYSTEMD_USER_DIR/csu-autoauth.service"

if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s\n' "systemctl not found. This installer requires systemd user services." >&2
    exit 1
fi

collect_config
write_config "$BASE_DIR/../common/csu-autoauth.sh"

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

printf '%s\n' "Installed script: $SCRIPT_DST"
printf '%s\n' "Installed config: $CONFIG_DST"
printf '%s\n' "Installed service: $SERVICE_DST"
printf '%s\n' "Log file: $LOG_FILE"
