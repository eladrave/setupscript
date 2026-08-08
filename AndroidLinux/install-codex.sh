#!/usr/bin/env bash
# Install or update OpenAI Codex CLI using the official standalone installer.

set -Eeuo pipefail

log() {
    printf '[codex-installer] %s\n' "$*"
}

die() {
    printf '[codex-installer] ERROR: %s\n' "$*" >&2
    exit 1
}

if (( EUID == 0 )); then
    die "Run this as a normal user, not as root."
fi

if ! command -v curl >/dev/null 2>&1; then
    command -v sudo >/dev/null 2>&1 || die "curl is required."
    command -v apt >/dev/null 2>&1 || die "curl is required."
    sudo apt update
    sudo apt install -y curl ca-certificates
fi

log "Running OpenAI's official standalone Codex installer..."
curl -fsSL https://chatgpt.com/codex/install.sh | sh

export PATH="$HOME/.local/bin:$PATH"
command -v codex >/dev/null 2>&1 || die "Codex was installed, but $HOME/.local/bin is not available on PATH."

log "Installed: $(codex --version)"
log "Run 'codex' and choose Sign in with ChatGPT the first time."
