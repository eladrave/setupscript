#!/usr/bin/env bash
# Set up and launch XFCE in Android's built-in Linux Development Environment.
#
# This targets the Google Pixel Terminal app backed by the Android
# Virtualization Framework. It is not intended for Termux, DroidDesk, or VNC.

set -Eeuo pipefail

SCRIPT_NAME="${0##*/}"
SCRIPT_URL="https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/android-linux-xfce.sh"
LAUNCHER_PATH="$HOME/.local/bin/android-linux-xfce"
AUTOSTART_BEGIN="# >>> android-linux-xfce autostart >>>"
AUTOSTART_END="# <<< android-linux-xfce autostart <<<"
SETUP_ONLY=false
FORCE_SETUP=false
ENABLE_AUTOSTART=true
TEMP_FILES=()

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--setup-only | --setup | --no-autostart]

With no option, install missing components, enable guarded autostart, and
launch XFCE.

  --setup-only   Install/configure XFCE and autostart, but do not launch.
  --setup        Run setup even when the required commands already exist,
                 then launch XFCE.
  --no-autostart Do not create or update the shell autostart hook.
  -h, --help     Show this help.
EOF
}

log() {
    printf '[android-xfce] %s\n' "$*"
}

die() {
    printf '[android-xfce] ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    local path
    for path in "${TEMP_FILES[@]}"; do
        [[ -n "$path" ]] && rm -f -- "$path"
    done
}

on_error() {
    local exit_code=$?
    printf '\n[android-xfce] The operation failed (exit %s).\n' "$exit_code" >&2
    printf '[android-xfce] If the message included "Input/output error", use\n' >&2
    printf '[android-xfce] the Android Terminal notification\047s Quit action, reboot\n' >&2
    printf '[android-xfce] the phone, and run this script again. Do not reset the VM.\n' >&2
    exit "$exit_code"
}

trap cleanup EXIT
trap on_error ERR

for arg in "$@"; do
    case "$arg" in
        --setup-only)
            SETUP_ONLY=true
            ;;
        --setup)
            FORCE_SETUP=true
            ;;
        --no-autostart)
            ENABLE_AUTOSTART=false
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

install_launcher_copy() {
    local source_path=""
    local download_path=""

    mkdir -p -- "${LAUNCHER_PATH%/*}"

    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        source_path="$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || true)"
    fi

    if [[ -n "$source_path" && -f "$source_path" && -r "$source_path" ]]; then
        if [[ "$source_path" != "$LAUNCHER_PATH" ]]; then
            install -m 0755 -- "$source_path" "$LAUNCHER_PATH"
        else
            chmod 0755 -- "$LAUNCHER_PATH"
        fi
        return
    fi

    command -v curl >/dev/null 2>&1 || die "curl is required when this script is executed from standard input."
    download_path="$(mktemp)"
    TEMP_FILES+=("$download_path")
    curl -fsSL --retry 3 "$SCRIPT_URL" -o "$download_path"
    bash -n "$download_path"
    install -m 0755 -- "$download_path" "$LAUNCHER_PATH"
}

install_autostart() {
    local bashrc_path="$HOME/.bashrc"
    local rewritten_path

    install_launcher_copy
    touch "$bashrc_path"
    rewritten_path="$(mktemp "${bashrc_path}.XXXXXX")"
    TEMP_FILES+=("$rewritten_path")

    awk -v begin="$AUTOSTART_BEGIN" -v end="$AUTOSTART_END" '
        $0 == begin { skipping = 1; next }
        $0 == end   { skipping = 0; next }
        !skipping   { print }
    ' "$bashrc_path" > "$rewritten_path"

    cat >> "$rewritten_path" <<'EOF'

# >>> android-linux-xfce autostart >>>
if [[ $- == *i* ]] && [[ -z "${SSH_CONNECTION:-}" ]] && [[ -z "${ANDROID_XFCE_NO_AUTOSTART:-}" ]]; then
    _android_xfce_launcher="$HOME/.local/bin/android-linux-xfce"
    _android_xfce_runtime="${XDG_RUNTIME_DIR:-/tmp}"
    if [[ ! -d "$_android_xfce_runtime" ]] || [[ ! -w "$_android_xfce_runtime" ]]; then
        _android_xfce_runtime="/tmp"
    fi
    _android_xfce_lock="${_android_xfce_runtime%/}/android-xfce-autostart-${UID}.lock"

    if [[ -x "$_android_xfce_launcher" ]] && command -v flock >/dev/null 2>&1; then
        exec 9>"$_android_xfce_lock"
        if flock -n 9 && ! pgrep -u "$USER" -x xfce4-session >/dev/null 2>&1; then
            "$_android_xfce_launcher" --no-autostart || true
        fi
        exec 9>&-
    fi

    unset _android_xfce_launcher _android_xfce_runtime _android_xfce_lock
fi
# <<< android-linux-xfce autostart <<<
EOF

    chmod --reference="$bashrc_path" "$rewritten_path"
    mv -f -- "$rewritten_path" "$bashrc_path"
    log "Autostart enabled in $bashrc_path."
    log "Persistent launcher installed at $LAUNCHER_PATH."
}

needs_setup=false
command -v startxfce4 >/dev/null 2>&1 || needs_setup=true
command -v labwc >/dev/null 2>&1 || needs_setup=true
command -v flock >/dev/null 2>&1 || needs_setup=true

setup_desktop() {
    log "Checking Debian package configuration..."
    sudo dpkg --configure -a
    sudo apt --fix-broken install -y

    log "Updating package metadata..."
    sudo apt update

    log "Installing XFCE and the Labwc Wayland compositor..."
    sudo apt install -y task-xfce-desktop labwc util-linux

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

if [[ "$ENABLE_AUTOSTART" == true ]]; then
    install_autostart
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

if [[ ! -r /dev/tty ]]; then
    die "No interactive terminal is available for the display confirmation."
fi
read -r </dev/tty

log "Starting XFCE. The desktop may initially appear inside a window."
log "Use the window's maximize button or Alt+F10 to fill the display."

exec startxfce4 --wayland
