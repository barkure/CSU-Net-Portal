#!/bin/sh

set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
HOME_DIR="${HOME:?HOME is not set}"
BIN_DIR="$HOME_DIR/.local/bin"
CONFIG_DIR="$HOME_DIR/.config/csu-autoauth"
LOG_DIR="$HOME_DIR/Library/Logs/csu-autoauth"
LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
SCRIPT_DST="$BIN_DIR/csu-autoauth"
CONFIG_DST="$CONFIG_DIR/config.conf"
PLIST_DST="$LAUNCH_AGENTS_DIR/com.barkure.csu-autoauth.plist"

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$LOG_DIR" "$LAUNCH_AGENTS_DIR"
install -m 755 "$BASE_DIR/csu-autoauth.sh" "$SCRIPT_DST"

if [ ! -f "$CONFIG_DST" ]; then
    install -m 644 "$BASE_DIR/config.conf.example" "$CONFIG_DST"
fi

cat > "$PLIST_DST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.barkure.csu-autoauth</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-lc</string>
        <string>$SCRIPT_DST</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$LOG_DIR/launchd.out.log</string>

    <key>StandardErrorPath</key>
    <string>$LOG_DIR/launchd.err.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
launchctl load "$PLIST_DST"

printf '%s\n' "Installed script: $SCRIPT_DST"
printf '%s\n' "Installed config: $CONFIG_DST"
printf '%s\n' "Installed plist: $PLIST_DST"
