#!/usr/bin/env bash
# Install XFCE as a Weston-triggered user service in Android's built-in Linux VM.
#
# After setup, opening Android Terminal starts Android's display bridge. Tapping
# the Display button then causes XFCE to launch automatically, without returning
# to the terminal or pressing Enter.

set -Eeuo pipefail

SCRIPT_NAME="${0##*/}"
SESSION_LAUNCHER="$HOME/.local/bin/android-linux-xfce-session"
USER_UNIT_DIR="$HOME/.config/systemd/user"
USER_UNIT_PATH="$USER_UNIT_DIR/android-xfce.service"
BASHRC_PATH="$HOME/.bashrc"
OLD_HOOK_BEGIN="# >>> android-linux-xfce autostart >>>"
OLD_HOOK_END="# <<< android-linux-xfce autostart <<<"
NEW_HOOK_BEGIN="# >>> android-linux-xfce systemd autostart >>>"
NEW_HOOK_END="# <<< android-linux-xfce systemd autostart <<<"
SETUP_ONLY=false
TEMP_FILES=()

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--setup-only]

Installs XFCE and a user service tied to Android's Weston display service.

  --setup-only  Install and configure everything without starting the display
                bridge now. Open a new Terminal session to start it later.
  -h, --help    Show this help.
EOF
}

log() {
    printf '[android-xfce-systemd] %s\n' "$*"
}

die() {
    printf '[android-xfce-systemd] ERROR: %s\n' "$*" >&2
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
    printf '\n[android-xfce-systemd] Setup failed with exit code %s.\n' "$exit_code" >&2
    printf '[android-xfce-systemd] If commands report "Input/output error", use\n' >&2
    printf '[android-xfce-systemd] the Android Terminal notification\047s Quit action,\n' >&2
    printf '[android-xfce-systemd] reboot the phone, and run this script again.\n' >&2
    exit "$exit_code"
}

trap cleanup EXIT
trap on_error ERR

for arg in "$@"; do
    case "$arg" in
        --setup-only)
            SETUP_ONLY=true
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

command -v systemctl >/dev/null 2>&1 || die "systemd is required."

log "Completing any interrupted Debian package operations..."
sudo env DEBIAN_FRONTEND=noninteractive dpkg --configure -a
sudo env DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y

log "Updating package metadata..."
sudo apt update

log "Installing XFCE, Labwc, and display readiness tools..."
sudo env DEBIAN_FRONTEND=noninteractive apt install -y \
    task-xfce-desktop labwc x11-utils util-linux dbus-x11

log "Preventing LightDM from competing with Android's Weston display service..."
sudo systemctl set-default multi-user.target
sudo systemctl disable --now lightdm.service 2>/dev/null || true

systemctl --user stop android-xfce.service 2>/dev/null || true
mkdir -p -- "${SESSION_LAUNCHER%/*}" "$USER_UNIT_DIR"

session_temp="$(mktemp)"
TEMP_FILES+=("$session_temp")
cat > "$session_temp" <<'SESSION_EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

log() {
    printf '[android-xfce-session] %s\n' "$*"
}

if pgrep -u "$USER" -x xfce4-session >/dev/null 2>&1; then
    log "An XFCE session is already running."
    exit 0
fi

export DISPLAY="${DISPLAY:-:0}"
export WLR_BACKENDS=x11
export XKB_DEFAULT_LAYOUT="${XKB_DEFAULT_LAYOUT:-us}"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=XFCE

for (( attempt = 1; attempt <= 120; attempt++ )); do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        log "Android display $DISPLAY is ready. Starting XFCE."
        exec startxfce4 --wayland
    fi

    if (( attempt == 1 || attempt % 10 == 0 )); then
        log "Waiting for the Android Display activity... ($attempt/120)"
    fi
    sleep 1
done

log "Android display $DISPLAY was not ready after 120 seconds."
ls -la /tmp/.X11-unix 2>&1 || true
systemctl --user --no-pager -l status weston.service 2>&1 || true
exit 1
SESSION_EOF
install -m 0755 -- "$session_temp" "$SESSION_LAUNCHER"

unit_temp="$(mktemp)"
TEMP_FILES+=("$unit_temp")
cat > "$unit_temp" <<'UNIT_EOF'
[Unit]
Description=XFCE desktop nested in Android's Weston display
Documentation=https://github.com/eladrave/setupscript/tree/main/AndroidLinux
Requires=weston.service
After=weston.service
PartOf=weston.service

[Service]
Type=simple
ExecStart=%h/.local/bin/android-linux-xfce-session
Restart=on-failure
RestartSec=5s
TimeoutStopSec=15s
KillMode=control-group

[Install]
WantedBy=weston.service
UNIT_EOF
install -m 0644 -- "$unit_temp" "$USER_UNIT_PATH"

touch "$BASHRC_PATH"
bashrc_temp="$(mktemp "${BASHRC_PATH}.XXXXXX")"
TEMP_FILES+=("$bashrc_temp")

awk \
    -v old_begin="$OLD_HOOK_BEGIN" \
    -v old_end="$OLD_HOOK_END" \
    -v new_begin="$NEW_HOOK_BEGIN" \
    -v new_end="$NEW_HOOK_END" '
        $0 == old_begin || $0 == new_begin { skipping = 1; next }
        $0 == old_end || $0 == new_end     { skipping = 0; next }
        !skipping                           { print }
    ' "$BASHRC_PATH" > "$bashrc_temp"

cat >> "$bashrc_temp" <<'BASHRC_EOF'

# >>> android-linux-xfce systemd autostart >>>
if [[ $- == *i* ]] && [[ -z "${SSH_CONNECTION:-}" ]] && [[ -z "${ANDROID_XFCE_NO_AUTOSTART:-}" ]]; then
    if ! systemctl --user is-active --quiet weston.service; then
        # This starts Android's Weston/Xwayland bridge. The Display button
        # attaches Android's graphical activity to it.
        # shellcheck disable=SC1091
        source /usr/local/bin/enable_display || printf '[android-xfce] Unable to start Android display bridge.\n' >&2
    fi

    systemctl --user start android-xfce.service 2>/dev/null || \
        printf '[android-xfce] Unable to start android-xfce.service.\n' >&2
fi
# <<< android-linux-xfce systemd autostart <<<
BASHRC_EOF

chmod --reference="$BASHRC_PATH" "$bashrc_temp"
mv -f -- "$bashrc_temp" "$BASHRC_PATH"

log "Enabling the XFCE user service as a dependency of Weston..."
systemctl --user daemon-reload
systemctl --user enable android-xfce.service

log "Installation complete."
log "Session launcher: $SESSION_LAUNCHER"
log "User service: $USER_UNIT_PATH"

if [[ "$SETUP_ONLY" == true ]]; then
    log "Open a new Android Terminal session and tap Display to launch XFCE."
    exit 0
fi

log "Starting Android's display bridge and arming the XFCE service..."
# This starts Weston. The user service waits until the Android Display activity
# creates a usable X11 display.
# shellcheck disable=SC1091
source /usr/local/bin/enable_display
systemctl --user start android-xfce.service

printf '\n'
printf 'Tap the monitor/display button now.\n'
printf 'XFCE will appear automatically when Android\047s display is ready.\n'
printf 'You do not need to return here or press Enter.\n'
