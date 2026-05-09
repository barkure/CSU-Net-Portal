#!/bin/sh

set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$BASE_DIR/../common/install-common.sh"

LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
PLIST_DST="$LAUNCH_AGENTS_DIR/com.barkure.csu-autoauth.plist"

collect_config
write_config "$BASE_DIR/../common/csu-autoauth.sh"
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

printf '%s\n' "Installed script: $SCRIPT_DST"
printf '%s\n' "Installed config: $CONFIG_DST"
printf '%s\n' "Installed plist: $PLIST_DST"
printf '%s\n' "Log file: $LOG_FILE"
