# Android Linux desktop setup

These scripts configure Android's built-in Linux Development Environment, as enabled from Developer options on supported Pixel devices.

They target the Android Terminal Debian VM. They are not intended for Termux, DroidDesk, VNC, or a separately installed Linux container.

## Install XFCE and enable autostart

Open Android Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/android-linux-xfce.sh | bash
```

The script installs XFCE and Labwc, disables the conflicting LightDM service, installs a persistent launcher at `~/.local/bin/android-linux-xfce`, and enables guarded autostart in `~/.bashrc`.

Autostart is enabled by default. When Android Terminal opens after a VM or phone restart, the launcher starts automatically. Android still requires this graphical handoff:

1. Tap the monitor/display button when prompted.
2. Return to the terminal tab.
3. Press Enter.
4. If XFCE appears inside a window named `wlroots - X11-1`, maximize it or press `Alt+F10`.

The hook runs only in an interactive local shell, skips SSH sessions, and avoids starting a second XFCE session.

### Launcher options

```bash
~/.local/bin/android-linux-xfce --setup-only   # Configure without launching now
~/.local/bin/android-linux-xfce --setup        # Repeat package setup, then launch
~/.local/bin/android-linux-xfce --no-autostart # Launch without changing the hook
~/.local/bin/android-linux-xfce --help
```

## Enable autostart on an existing installation

If you previously ran an older version of the XFCE script, run:

```bash
curl -fsSL https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/enableautostart | bash
```

This downloads the latest launcher to `~/.local/bin/android-linux-xfce` and adds or repairs the guarded `~/.bashrc` hook. It is safe to run more than once.

## Install Google Chrome

```bash
curl -fsSL https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/install-chrome.sh | bash
```

The installer detects `arm64` or `amd64`, downloads the matching official Google Chrome `.deb`, validates its architecture, and installs it with `apt`.

## Install OpenAI Codex CLI

```bash
curl -fsSL https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/install-codex.sh | bash
```

This wrapper uses OpenAI's official standalone installer:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

After installation, run `codex` and choose **Sign in with ChatGPT**.

## Install Warp Terminal

```bash
curl -fsSL https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/install-warp.sh | bash
```

The installer detects `arm64` or `amd64`, downloads Warp's matching official Debian package, validates its architecture, and installs `warp-terminal`. Start it from the XFCE Applications menu or run:

```bash
warp-terminal
```

## Troubleshooting

If commands suddenly report `Input/output error`, use the Android Terminal notification's **Quit** action, reboot the phone, and run the relevant script again. Do not reset the Linux VM unless you intend to erase it.

The XFCE notification daemon may warn that the Wayland compositor does not support `wlr-layer-shell`. That warning does not prevent the desktop from running.

## Upstream installation sources

- [OpenAI Codex CLI](https://developers.openai.com/codex/cli)
- [Warp installation documentation](https://docs.warp.dev/getting-started/quickstart/installation-and-setup/)
- [Google Chrome Debian packages](https://dl.google.com/linux/direct/)
