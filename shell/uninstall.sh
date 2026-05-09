#!/bin/sh

set -eu

HOME_DIR="${HOME:?HOME is not set}"
OS_NAME="$(uname -s)"

remove_common_files() {
    rm -f "$HOME_DIR/.local/bin/csu-autoauth"
    rm -f "$HOME_DIR/.config/csu-autoauth/config.conf"
    rmdir "$HOME_DIR/.config/csu-autoauth" >/dev/null 2>&1 || true
    rm -f "$HOME_DIR/.local/share/csu-autoauth/csu-autoauth.log"
    rm -f "$HOME_DIR/.local/share/csu-autoauth/launchd.out.log"
    rm -f "$HOME_DIR/.local/share/csu-autoauth/launchd.err.log"
    rmdir "$HOME_DIR/.local/share/csu-autoauth" >/dev/null 2>&1 || true
    printf '%s\n' "Removed script: $HOME_DIR/.local/bin/csu-autoauth"
    printf '%s\n' "Removed config dir: $HOME_DIR/.config/csu-autoauth"
    printf '%s\n' "Removed data dir: $HOME_DIR/.local/share/csu-autoauth"
}

uninstall_linux() {
    SERVICE_DST="$HOME_DIR/.config/systemd/user/csu-autoauth.service"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user disable --now csu-autoauth.service >/dev/null 2>&1 || true
        rm -f "$SERVICE_DST"
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    else
        rm -f "$SERVICE_DST"
    fi

    pkill -f "$HOME_DIR/.local/bin/csu-autoauth" >/dev/null 2>&1 || true
    printf '%s\n' "Removed service: $SERVICE_DST"
}

uninstall_macos() {
    PLIST_DST="$HOME_DIR/Library/LaunchAgents/com.barkure.csu-autoauth.plist"

    launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
    rm -f "$PLIST_DST"
    pkill -f "$HOME_DIR/.local/bin/csu-autoauth" >/dev/null 2>&1 || true

    printf '%s\n' "Removed plist: $PLIST_DST"
}

case "$OS_NAME" in
    Linux)
        uninstall_linux
        ;;
    Darwin)
        uninstall_macos
        ;;
    *)
        printf '%s\n' "Unsupported OS: $OS_NAME" >&2
        exit 1
        ;;
esac

remove_common_files
