#!/bin/sh

set -eu

if [ -x /etc/init.d/csu-autoauth ]; then
    /etc/init.d/csu-autoauth disable >/dev/null 2>&1 || true
    /etc/init.d/csu-autoauth stop >/dev/null 2>&1 || true
fi

rm -f /etc/init.d/csu-autoauth
rm -f /usr/bin/csu-autoauth.sh
rm -f /etc/config/csu-autoauth
rm -f /tmp/log/csu-autoauth.log

printf '%s\n' "Removed init script: /etc/init.d/csu-autoauth"
printf '%s\n' "Removed script: /usr/bin/csu-autoauth.sh"
printf '%s\n' "Removed config: /etc/config/csu-autoauth"
printf '%s\n' "Removed log file: /tmp/log/csu-autoauth.log"
