#!/bin/sh

set -eu

BASE_URL="${BASE_URL:-https://gh.barku.re/barkure/CSU-Net-Portal/releases/latest/download}"

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
need_cmd ubus
need_cmd jsonfilter

TARGET_FULL="$(ubus call system board | jsonfilter -e '@.release.target')"
VERSION="$(ubus call system board | jsonfilter -e '@.release.version')"
TARGET="$(printf '%s' "$TARGET_FULL" | cut -d/ -f1)"
SUBTARGET="$(printf '%s' "$TARGET_FULL" | cut -d/ -f2)"

if [ -z "$TARGET" ] || [ -z "$SUBTARGET" ] || [ -z "$VERSION" ]; then
    echo "Unable to detect OpenWrt target, subtarget, or version" >&2
    exit 1
fi

case "$VERSION" in
    25.*|26.*)
        need_cmd apk
        ARCH="$(apk --print-arch)"
        PKG="/tmp/csu-autoauth.apk"
        URL="${BASE_URL}/csu-autoauth-${TARGET}-${SUBTARGET}-${ARCH}.apk"
        download_file "$PKG" "$URL"
        apk add --allow-untrusted "$PKG"
        ;;
    24.*)
        need_cmd opkg
        ARCH="$(opkg print-architecture | while read -r _ arch _; do
            [ "$arch" != "all" ] && {
                printf '%s\n' "$arch"
                break
            }
        done)"
        PKG="/tmp/csu-autoauth.ipk"
        URL="${BASE_URL}/csu-autoauth-${TARGET}-${SUBTARGET}-${ARCH}.ipk"
        download_file "$PKG" "$URL"
        opkg install "$PKG"
        ;;
    *)
        echo "Unsupported OpenWrt version: $VERSION" >&2
        exit 1
        ;;
esac
