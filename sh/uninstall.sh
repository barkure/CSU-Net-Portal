#!/bin/sh

set -eu

is_openwrt() {
    [ -f /etc/openwrt_release ]
}

uninstall_openwrt() {
    if [ -x /etc/init.d/csu-net-auth ]; then
        /etc/init.d/csu-net-auth disable >/dev/null 2>&1 || true
        /etc/init.d/csu-net-auth stop >/dev/null 2>&1 || true
    fi

    rm -f /etc/init.d/csu-net-auth
    rm -f /usr/bin/csu-net-auth.sh
    rm -f /etc/config/csu-net-auth
    rm -f /var/log/csu-net-auth.log /var/log/csu-net-auth.log.1

    printf '%s\n' "Removed init script: /etc/init.d/csu-net-auth"
    printf '%s\n' "Removed script: /usr/bin/csu-net-auth.sh"
    printf '%s\n' "Removed config: /etc/config/csu-net-auth"
    printf '%s\n' "Removed log file: /var/log/csu-net-auth.log"
}

remove_common_files() {
    HOME_DIR="${HOME:?HOME is not set}"

    rm -f "$HOME_DIR/.local/bin/csu-net-auth"
    rm -f "$HOME_DIR/.config/csu-net-auth/config.conf"
    rmdir "$HOME_DIR/.config/csu-net-auth" >/dev/null 2>&1 || true
    rm -f "$HOME_DIR/.local/share/csu-net-auth/csu-net-auth.log"
    rm -f "$HOME_DIR/.local/share/csu-net-auth/csu-net-auth.log.1"
    rm -f "$HOME_DIR/.local/share/csu-net-auth/launchd.out.log"
    rm -f "$HOME_DIR/.local/share/csu-net-auth/launchd.err.log"
    rmdir "$HOME_DIR/.local/share/csu-net-auth" >/dev/null 2>&1 || true
    printf '%s\n' "Removed script: $HOME_DIR/.local/bin/csu-net-auth"
    printf '%s\n' "Removed config dir: $HOME_DIR/.config/csu-net-auth"
    printf '%s\n' "Removed data dir: $HOME_DIR/.local/share/csu-net-auth"
}

uninstall_linux() {
    HOME_DIR="${HOME:?HOME is not set}"
    SERVICE_DST="$HOME_DIR/.config/systemd/user/csu-net-auth.service"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user disable --now csu-net-auth.service >/dev/null 2>&1 || true
        rm -f "$SERVICE_DST"
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    else
        rm -f "$SERVICE_DST"
    fi

    pkill -f "$HOME_DIR/.local/bin/csu-net-auth" >/dev/null 2>&1 || true
    printf '%s\n' "Removed service: $SERVICE_DST"
}

uninstall_macos() {
    HOME_DIR="${HOME:?HOME is not set}"
    PLIST_DST="$HOME_DIR/Library/LaunchAgents/com.barkure.csu-net-auth.plist"

    launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
    rm -f "$PLIST_DST"
    pkill -f "$HOME_DIR/.local/bin/csu-net-auth" >/dev/null 2>&1 || true

    printf '%s\n' "Removed plist: $PLIST_DST"
}

if is_openwrt; then
    uninstall_openwrt
    exit 0
fi

case "$(uname -s)" in
    Linux)
        uninstall_linux
        ;;
    Darwin)
        uninstall_macos
        ;;
    *)
        printf '%s\n' "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

remove_common_files
