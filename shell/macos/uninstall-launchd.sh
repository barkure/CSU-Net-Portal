#!/bin/sh

set -eu

HOME_DIR="${HOME:?HOME is not set}"
LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
PLIST_DST="$LAUNCH_AGENTS_DIR/com.barkure.csu-autoauth.plist"

launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
rm -f "$PLIST_DST"

pkill -f "$HOME_DIR/.local/bin/csu-autoauth" >/dev/null 2>&1 || true

printf '%s\n' "Removed plist: $PLIST_DST"
