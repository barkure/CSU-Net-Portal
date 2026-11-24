#!/bin/sh

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -f "$REPO_ROOT/.env" ]; then
    # shellcheck disable=SC1091
    set -a
    . "$REPO_ROOT/.env"
    set +a
fi

HOST="${CSUNET_SSH_HOST:-e2-micro-usw1}"
REMOTE_ROOT="${CSUNET_REMOTE_ROOT:-/var/www/html/csunet}"

WINSW_VERSION="${WINSW_VERSION:-2.12.0}"
BITIFUL_BUCKET="${BITIFUL_BUCKET:-barkure-assets}"
BITIFUL_ENDPOINT="${BITIFUL_ENDPOINT:-https://s3.bitiful.net}"
BITIFUL_REGION="${BITIFUL_REGION:-cn-east-1}"

sync_scripts() {
    ssh "$HOST" "mkdir -p '$REMOTE_ROOT/sh/common' '$REMOTE_ROOT/sh/openwrt' '$REMOTE_ROOT/pwsh/common'"

    # One tarball + scp avoids broken stdin piping through IAP ProxyCommand.
    tar_path="$(mktemp "${TMPDIR:-/tmp}/csunet-sync.XXXXXX.tar")"
    # shellcheck disable=SC2064
    trap "rm -f '$tar_path'" EXIT

    (
        cd "$REPO_ROOT"
        tar -cf "$tar_path" \
            sh/install.sh \
            sh/uninstall.sh \
            sh/common/csu-net-auth.sh \
            sh/common/config.conf.example \
            sh/openwrt/csu-net-auth.sh \
            sh/openwrt/csu-net-auth.init \
            sh/openwrt/csu-net-auth.config \
            pwsh/install.ps1 \
            pwsh/uninstall.ps1 \
            pwsh/common/install-main.ps1 \
            pwsh/common/uninstall-main.ps1 \
            pwsh/common/csu-net-auth.ps1 \
            pwsh/common/config.ps1.example
    )

    printf '%s\n' "put $HOST:$REMOTE_ROOT/ <- $tar_path"
    scp -q "$tar_path" "$HOST:/tmp/csunet-sync.tar"
    ssh "$HOST" "tar -xf /tmp/csunet-sync.tar -C '$REMOTE_ROOT' && rm -f /tmp/csunet-sync.tar && find '$REMOTE_ROOT' -type f -exec chmod 644 {} +"
    rm -f "$tar_path"
    trap - EXIT

    printf '%s\n' "Synced scripts to https://ssuu.us/csunet/ ($HOST:$REMOTE_ROOT/)"
}

sync_winsw() {
    if [ -z "${BITIFUL_ACCESS_KEY_ID:-}" ] || [ -z "${BITIFUL_SECRET_ACCESS_KEY:-}" ]; then
        printf '%s\n' "Skip WinSW: set BITIFUL_ACCESS_KEY_ID and BITIFUL_SECRET_ACCESS_KEY to upload."
        return 0
    fi

    src_dir="$(mktemp -d "${TMPDIR:-/tmp}/csunet-winsw.XXXXXX")"
    # shellcheck disable=SC2064
    trap "rm -rf '$src_dir'" EXIT

    for name in WinSW-x64.exe WinSW-x86.exe; do
        printf '%s\n' "download $name"
        curl -fsSL "https://github.com/winsw/winsw/releases/download/v${WINSW_VERSION}/$name" -o "$src_dir/$name"
    done

    BITIFUL_BUCKET="$BITIFUL_BUCKET" \
    BITIFUL_ENDPOINT="$BITIFUL_ENDPOINT" \
    BITIFUL_REGION="$BITIFUL_REGION" \
    WINSW_VERSION="$WINSW_VERSION" \
    WINSW_SRC_DIR="$src_dir" \
    python3 - <<'PY'
import os
import boto3
from botocore.client import Config

src_dir = os.environ["WINSW_SRC_DIR"]
bucket = os.environ["BITIFUL_BUCKET"]
endpoint = os.environ["BITIFUL_ENDPOINT"]
region = os.environ["BITIFUL_REGION"]
version = os.environ["WINSW_VERSION"]

client = boto3.client(
    "s3",
    aws_access_key_id=os.environ["BITIFUL_ACCESS_KEY_ID"],
    aws_secret_access_key=os.environ["BITIFUL_SECRET_ACCESS_KEY"],
    endpoint_url=endpoint,
    region_name=region,
    config=Config(s3={"addressing_style": "virtual"}),
)
for name in ("WinSW-x64.exe", "WinSW-x86.exe"):
    key = f"winsw/{version}/{name}"
    path = os.path.join(src_dir, name)
    print(f"put s3://{bucket}/{key} <- {path}")
    client.upload_file(path, bucket, key, ExtraArgs={"ContentType": "application/octet-stream"})
print(f"Synced WinSW to https://dl.barkure.cn/winsw/{version}/")
PY

    rm -rf "$src_dir"
    trap - EXIT
}

sync_scripts
sync_winsw
