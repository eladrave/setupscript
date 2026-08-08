# XFCE for Android Linux

This script installs and launches an XFCE desktop in Android's built-in Linux Development Environment, as enabled from Developer options on supported Pixel devices.

It is intended for the Android Terminal Debian VM. It is not for Termux, DroidDesk, VNC, or a separately installed Linux container.

## Download and run

Open the Android Terminal command prompt and run:

```bash
sudo apt update && sudo apt install -y curl
curl -fsSL https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/android-linux-xfce.sh -o android-linux-xfce.sh
chmod +x android-linux-xfce.sh
./android-linux-xfce.sh
```

Or use one command:

```bash
curl -fsSL https://raw.githubusercontent.com/eladrave/setupscript/main/AndroidLinux/android-linux-xfce.sh -o android-linux-xfce.sh && chmod +x android-linux-xfce.sh && ./android-linux-xfce.sh
```

Do not pipe the download directly into `bash`. The launcher pauses for input while Android opens the graphical display.

## What to do when it starts

1. Let the package installation finish.
2. When prompted, tap the monitor/display button in the Android Terminal app.
3. Return to the terminal tab and press Enter.
4. If XFCE opens inside a window named `wlroots - X11-1`, maximize it with the window button or press `Alt+F10`.

The first installation can take several minutes.

## Options

```bash
./android-linux-xfce.sh --setup-only  # Install and configure without launching
./android-linux-xfce.sh --setup       # Repeat setup, then launch
./android-linux-xfce.sh --help        # Show help
```

After the initial setup, launch the desktop again with:

```bash
./android-linux-xfce.sh
```

## Troubleshooting

If commands suddenly report `Input/output error`, use the Android Terminal notification's **Quit** action, reboot the phone, and run the script again. Do not reset the Linux VM unless you intend to erase it.

The XFCE notification daemon may warn that the Wayland compositor does not support `wlr-layer-shell`. That warning does not prevent the desktop from running.
