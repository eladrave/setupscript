#!/usr/bin/env bash
# Install Warp Terminal using Warp's official Debian package.

set -Eeuo pipefail

TEMP_DIR=""

log() {
    printf '[warp-installer] %s\n' "$*"
}

die() {
    printf '[warp-installer] ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    [[ -n "$TEMP_DIR" ]] && rm -rf -- "$TEMP_DIR"
}

trap cleanup EXIT

if (( EUID == 0 )); then
    die "Run this as a normal user. The script uses sudo when needed."
fi

command -v sudo >/dev/null 2>&1 || die "sudo is required."
command -v apt >/dev/null 2>&1 || die "This installer requires Debian or Ubuntu with apt."

architecture="$(dpkg --print-architecture)"
case "$architecture" in
    arm64)
        warp_package="deb_arm64"
        ;;
    amd64)
        warp_package="deb"
        ;;
    *)
        die "Warp does not provide a Debian package for architecture: $architecture"
        ;;
esac

sudo apt update
sudo apt install -y curl ca-certificates

TEMP_DIR="$(mktemp -d)"
package_path="$TEMP_DIR/warp-terminal.deb"

log "Downloading Warp's official $architecture Debian package..."
curl -fL --retry 3 "https://app.warp.dev/download?package=$warp_package" -o "$package_path"
dpkg-deb --info "$package_path" >/dev/null

package_architecture="$(dpkg-deb -f "$package_path" Architecture)"
if [[ "$package_architecture" != "$architecture" ]]; then
    die "Downloaded package architecture is $package_architecture, expected $architecture."
fi

log "Installing Warp Terminal..."
sudo apt install -y "$package_path"

dpkg-query -W -f='[warp-installer] Installed: ${Package} ${Version}\n' warp-terminal
log "Start Warp from the XFCE Applications menu or run: warp-terminal"
