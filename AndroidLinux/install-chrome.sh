#!/usr/bin/env bash
# Install Google Chrome on Debian, including Pixel ARM64 systems.

set -Eeuo pipefail

TEMP_DIR=""

log() {
    printf '[browser-installer] %s\n' "$*"
}

die() {
    printf '[browser-installer] ERROR: %s\n' "$*" >&2
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

log "Updating package metadata..."
sudo dpkg --configure -a
sudo apt --fix-broken install -y
sudo apt update

case "$architecture" in
    arm64|amd64)
        sudo apt install -y curl ca-certificates
        TEMP_DIR="$(mktemp -d)"
        package_path="$TEMP_DIR/google-chrome-stable_current_${architecture}.deb"

        log "Downloading the official Google Chrome $architecture Debian package..."
        curl -fL --retry 3 \
            "https://dl.google.com/linux/direct/google-chrome-stable_current_${architecture}.deb" \
            -o "$package_path"
        dpkg-deb --info "$package_path" >/dev/null

        package_architecture="$(dpkg-deb -f "$package_path" Architecture)"
        if [[ "$package_architecture" != "$architecture" ]]; then
            die "Downloaded package architecture is $package_architecture, expected $architecture."
        fi

        log "Installing Google Chrome..."
        sudo apt install -y "$package_path"
        command -v google-chrome-stable >/dev/null 2>&1 || die "Chrome installation completed, but google-chrome-stable was not found."
        log "Installed: $(google-chrome-stable --version)"
        ;;
    *)
        die "Unsupported Debian architecture: $architecture"
        ;;
esac

log "The browser is available from the XFCE Applications menu."
