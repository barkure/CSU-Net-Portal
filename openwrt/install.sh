#!/bin/sh

set -eu


need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

download_file() {
    output_path="$1"
    url="$2"
    curl -fL "$url" -o "$output_path"
}

need_cmd curl


mkdir -p /usr/bin /etc/init.d /etc/config

download_file "/usr/bin/csu-autoauth.sh" "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/csu-autoauth.sh"
download_file "/etc/init.d/csu-autoauth" "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/csu-autoauth.init"

if [ ! -f /etc/config/csu-autoauth ]; then
    download_file "/etc/config/csu-autoauth" "https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/csu-autoauth.config"
fi

chmod 755 /usr/bin/csu-autoauth.sh /etc/init.d/csu-autoauth

/etc/init.d/csu-autoauth enable

printf '%s\n' "Installed script: /usr/bin/csu-autoauth.sh"
printf '%s\n' "Installed init script: /etc/init.d/csu-autoauth"
printf '%s\n' "Installed config: /etc/config/csu-autoauth"
printf '%s\n' "Log file: /var/log/csu-autoauth.log"
printf '%s\n' "Next: configure UCI values, then run /etc/init.d/csu-autoauth restart"
