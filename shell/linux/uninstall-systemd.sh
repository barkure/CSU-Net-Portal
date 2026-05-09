#!/bin/sh

set -eu

HOME_DIR="${HOME:?HOME is not set}"
SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"
SERVICE_DST="$SYSTEMD_USER_DIR/csu-autoauth.service"

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now csu-autoauth.service >/dev/null 2>&1 || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

rm -f "$SERVICE_DST"
pkill -f "$HOME_DIR/.local/bin/csu-autoauth" >/dev/null 2>&1 || true
rm -f "$HOME_DIR/.local/bin/csu-autoauth"
rm -f "$HOME_DIR/.config/csu-autoauth/config.conf"
rmdir "$HOME_DIR/.config/csu-autoauth" >/dev/null 2>&1 || true
rm -f "$HOME_DIR/.local/share/csu-autoauth/csu-autoauth.log"
rm -f "$HOME_DIR/.local/share/csu-autoauth/launchd.out.log"
rm -f "$HOME_DIR/.local/share/csu-autoauth/launchd.err.log"
rmdir "$HOME_DIR/.local/share/csu-autoauth" >/dev/null 2>&1 || true

printf '%s\n' "Removed service: $SERVICE_DST"
printf '%s\n' "Removed config dir: $HOME_DIR/.config/csu-autoauth"
printf '%s\n' "Removed data dir: $HOME_DIR/.local/share/csu-autoauth"
