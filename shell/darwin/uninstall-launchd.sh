#!/bin/sh

set -eu

HOME_DIR="${HOME:?HOME is not set}"
LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
PLIST_DST="$LAUNCH_AGENTS_DIR/com.barkure.csu-autoauth.plist"

launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
rm -f "$PLIST_DST"

pkill -f "$HOME_DIR/.local/bin/csu-autoauth" >/dev/null 2>&1 || true
rm -f "$HOME_DIR/.local/bin/csu-autoauth"
rm -f "$HOME_DIR/.config/csu-autoauth/config.conf"
rmdir "$HOME_DIR/.config/csu-autoauth" >/dev/null 2>&1 || true
rm -f "$HOME_DIR/.local/share/csu-autoauth/csu-autoauth.log"
rm -f "$HOME_DIR/.local/share/csu-autoauth/launchd.out.log"
rm -f "$HOME_DIR/.local/share/csu-autoauth/launchd.err.log"
rmdir "$HOME_DIR/.local/share/csu-autoauth" >/dev/null 2>&1 || true

printf '%s\n' "Removed plist: $PLIST_DST"
printf '%s\n' "Removed config dir: $HOME_DIR/.config/csu-autoauth"
printf '%s\n' "Removed data dir: $HOME_DIR/.local/share/csu-autoauth"
