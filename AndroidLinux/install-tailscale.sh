#!/usr/bin/env bash

set -Eeuo pipefail

readonly TAILSCALE_INSTALL_URL="https://tailscale.com/install.sh"
AUTH_KEY_FILE=""

log() {
    printf '[android-tailscale] %s\n' "$*"
}

cleanup() {
    if [[ -n "$AUTH_KEY_FILE" && -f "$AUTH_KEY_FILE" ]]; then
        rm -f -- "$AUTH_KEY_FILE"
    fi
}

trap cleanup EXIT

if [[ "$(uname -s)" != "Linux" ]]; then
    log "This installer must be run inside the Android Linux Debian terminal."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    log "sudo is required but was not found."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    log "curl is required but was not found."
    exit 1
fi

if [[ ! -c /dev/net/tun ]]; then
    log "The VM does not currently expose /dev/net/tun."
    log "Tailscale cannot provide normal VPN networking without the TUN device."
    log "Restart the Android Linux environment and try again."
    exit 1
fi

if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale is already installed."
else
    log "Installing Tailscale from its official Linux repository..."
    curl -fsSL "$TAILSCALE_INSTALL_URL" | sh
fi

log "Enabling and starting the Tailscale daemon..."
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now tailscaled
elif command -v service >/dev/null 2>&1; then
    sudo service tailscaled start
else
    log "Could not find systemctl or service to start tailscaled."
    exit 1
fi

if [[ -n "${TAILSCALE_AUTH_KEY:-}" ]]; then
    log "Authenticating with TAILSCALE_AUTH_KEY..."
    AUTH_KEY_FILE="$(mktemp)"
    chmod 600 "$AUTH_KEY_FILE"
    printf '%s' "$TAILSCALE_AUTH_KEY" >"$AUTH_KEY_FILE"
    sudo tailscale up --auth-key="file:$AUTH_KEY_FILE"
else
    log "Starting the Tailscale sign-in flow..."
    log "Open the URL printed below and authorize this Linux VM."
    sudo tailscale up
fi

log "Tailscale is connected and will start automatically with the Linux VM."
printf '\nTailscale addresses:\n'
tailscale ip || true
printf '\nTailscale status:\n'
tailscale status || true
