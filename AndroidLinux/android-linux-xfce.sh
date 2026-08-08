#!/usr/bin/env bash
# Set up and launch XFCE in Android's built-in Linux Development Environment.
#
# This targets the Google Pixel Terminal app backed by the Android
# Virtualization Framework. It is not intended for Termux, DroidDesk, or VNC.

set -Eeuo pipefail

SCRIPT_NAME="${0##*/}"
SETUP_ONLY=false
FORCE_SETUP=false

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--setup-only | --setup]

With no option, install missing components if necessary and launch XFCE.

  --setup-only  Install/configure XFCE and Labwc, but do not launch.
  --setup       Run setup even when the required commands already exist,
                then launch XFCE.
  -h, --help    Show this help.
EOF
}

log() {
    printf '[android-xfce] %s\n' "$*"
}

die() {
    printf '[android-xfce] ERROR: %s\n' "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    printf '\n[android-xfce] The operation failed (exit %s).\n' "$exit_code" >&2
    printf '[android-xfce] If the message included "Input/output error", use\n' >&2
    printf '[android-xfce] the Android Terminal notification\047s Quit action, reboot\n' >&2
    printf '[android-xfce] the phone, and run this script again. Do not reset the VM.\n' >&2
    exit "$exit_code"
}

trap on_error ERR

for arg in "$@"; do
    case "$arg" in
        --setup-only)
            SETUP_ONLY=true
            ;;
        --setup)
            FORCE_SETUP=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "Unknown option: $arg"
            ;;
    esac
done

if (( EUID == 0 )); then
    die "Run this as the normal droid user, not as root. The script uses sudo when needed."
fi

if [[ ! -f /usr/local/bin/enable_display ]]; then
    die "Android's /usr/local/bin/enable_display was not found. This script only supports the built-in Android Linux Terminal VM."
fi

needs_setup=false
command -v startxfce4 >/dev/null 2>&1 || needs_setup=true
command -v labwc >/dev/null 2>&1 || needs_setup=true

setup_desktop() {
    log "Checking Debian package configuration..."
    sudo dpkg --configure -a
    sudo apt --fix-broken install -y

    log "Updating package metadata..."
    sudo apt update

    log "Installing XFCE and the Labwc Wayland compositor..."
    sudo apt install -y task-xfce-desktop labwc

    log "Keeping the VM in console mode so LightDM does not compete with Android's Weston display service..."
    sudo systemctl set-default multi-user.target
    sudo systemctl disable --now lightdm.service 2>/dev/null || true

    log "Setup complete."
}

if [[ "$needs_setup" == true || "$FORCE_SETUP" == true ]]; then
    setup_desktop
else
    log "XFCE and Labwc are already installed."
fi

if [[ "$SETUP_ONLY" == true ]]; then
    exit 0
fi

if pgrep -u "$USER" -x xfce4-session >/dev/null 2>&1; then
    die "An XFCE session is already running. Log out of it before starting another session."
fi

log "Rotate the phone or external display to landscape now."
log "Enabling Android's graphical display bridge..."

# This must be sourced because it exports DISPLAY for the current shell.
# shellcheck disable=SC1091
source /usr/local/bin/enable_display

printf '\n'
printf '1. Tap the monitor/display button in the Android Terminal app.\n'
printf '2. After the graphical screen appears, return to this terminal tab.\n'
printf '3. Press Enter here to launch XFCE through Labwc.\n'
read -r

log "Starting XFCE. The desktop may initially appear inside a window."
log "Use the window's maximize button or Alt+F10 to fill the display."

exec startxfce4 --wayland
