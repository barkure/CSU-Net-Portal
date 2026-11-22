#!/bin/sh

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUCKET="${CSUNET_R2_BUCKET:-ssuu-us}"
PREFIX="${CSUNET_R2_PREFIX:-csunet}"
PREFIX="${PREFIX#/}"
PREFIX="${PREFIX%/}"

WRANGLER="npx --yes wrangler"

upload() {
    local_path="$1"
    object_key="$2"
    content_type="${3:-text/plain; charset=utf-8}"

    if [ ! -f "$local_path" ]; then
        printf '%s\n' "Missing file: $local_path" >&2
        exit 1
    fi

    printf '%s\n' "put $PREFIX/$object_key <- $local_path"
    $WRANGLER r2 object put "$BUCKET/$PREFIX/$object_key" \
        --file "$local_path" \
        --content-type "$content_type" \
        --remote
}

upload "$REPO_ROOT/sh/install.sh" "sh/install.sh"
upload "$REPO_ROOT/sh/uninstall.sh" "sh/uninstall.sh"
upload "$REPO_ROOT/sh/common/csu-net-auth.sh" "sh/common/csu-net-auth.sh"
upload "$REPO_ROOT/sh/common/config.conf.example" "sh/common/config.conf.example"
upload "$REPO_ROOT/sh/openwrt/csu-net-auth.sh" "sh/openwrt/csu-net-auth.sh"
upload "$REPO_ROOT/sh/openwrt/csu-net-auth.init" "sh/openwrt/csu-net-auth.init"
upload "$REPO_ROOT/sh/openwrt/csu-net-auth.config" "sh/openwrt/csu-net-auth.config"

upload "$REPO_ROOT/pwsh/install.ps1" "pwsh/install.ps1" "text/plain; charset=utf-8"
upload "$REPO_ROOT/pwsh/uninstall.ps1" "pwsh/uninstall.ps1" "text/plain; charset=utf-8"
upload "$REPO_ROOT/pwsh/common/install-main.ps1" "pwsh/common/install-main.ps1" "text/plain; charset=utf-8"
upload "$REPO_ROOT/pwsh/common/csu-net-auth.ps1" "pwsh/common/csu-net-auth.ps1" "text/plain; charset=utf-8"
upload "$REPO_ROOT/pwsh/common/config.ps1.example" "pwsh/common/config.ps1.example" "text/plain; charset=utf-8"

printf '%s\n' "Synced runtime objects to r2://$BUCKET/$PREFIX/"
