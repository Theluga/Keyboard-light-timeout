# Keyboard Timeout Profile Switcher (Solaar)

A custom Linux utility script designed to add an automatic backlight timeout profile switcher for backlit keyboards that lack a built-in hardware or BIOS timeout (specifically tailored for the Logitech G815 using **Solaar** on **Wayland**).

## Background & Motivation

Many modern keyboards and laptops lack proper firmware or BIOS controls for backlight timeouts. For example, some laptop BIOS updates remove ACPI/AC backlight timeout functionality entirely without manufacturer support fixes.

This project provides a lightweight userspace solution that monitors user inactivity via Wayland idle tools (`wprintidle`), tracks audio output changes (`wpctl`) to prevent unwanted wake triggers (like media playback), and dynamically switches Solaar onboard profiles to dim or turn off the keyboard backlight.

---

## Features

* **Idle Detection on Wayland:** Uses `wprintidle` to track user inactivity accurately in Wayland sessions (such as GNOME).
* **Smart Volume Interaction:** Detects audio stream changes (`wpctl`) and temporarily delays idle triggers if volume changes occur, preventing media consumption from being interrupted by dimming.
* **Solaar Profile Integration:** Automatically swaps between your active profile and an idle "dim" profile (e.g., `Profile 3`) when idle thresholds are met.
* **Resource Efficient:** Single-instance enforcement via `flock`, low CPU priority (`renice`), and minimal resource overhead.
* **Systemd Integration:** Runs reliably as a user service tied to your graphical session.

---

## Prerequisites & Dependencies

Make sure you have the following packages installed on your system:

* [Solaar](https://github.com/pwr-Solaar/solaar) (configured for your device, e.g., Logitech G815)
* [wprintidle](https://codeberg.org/andyscott/wprintidle) (for Wayland idle tracking)
* `wireplumber` / `pipewire` (`wpctl` for volume monitoring)
* `bash`, `awk`, `coreutils`

---

## Installation & Setup

### 1. Place the Script

Save the main script to your local binaries directory:

```bash
mkdir -p ~/.local/bin
# Save your script as:
~/.local/bin/kbd_timeout-no-volume_G815_Solaar.sh
chmod +x ~/.local/bin/kbd_timeout-no-volume_G815_Solaar.sh

```

### 2. Set Up the Systemd User Service

Create a systemd user service file to ensure the script starts automatically with your graphical session.

Create `~/.config/systemd/user/kbd-timeout.service`:

```ini
[Unit]
Description=Keyboard timeout profile switch (Solaar)
After=graphical-session.target

[Service]
ExecStartPre=/bin/bash -c "sleep 10"
ExecStart=%h/.local/bin/kbd_timeout-no-volume_G815_Solaar.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target

```

### 3. Enable and Start the Service

Reload systemd and enable the service for your user account:

```bash
systemctl --user daemon-reload
systemctl --user enable --now kbd-timeout.service

```

---

## Configuration

You can customize the script behavior by editing the variables at the top of `kbd_timeout-no-volume_G815_Solaar.sh`:

```bash
dim_time=15             # Seconds of inactivity before dimming the keyboard
idle_profile="Profile 3"# Solaar onboard profile to activate when idle
priority=19             # CPU nice priority for the script

```

---

## Alternative Methods

* Take inspiration on the `old` folder.
---

## Acknowledgments & Inspiration

* Inspired by [PartRobot's Guide on Setting Keyboard Backlight Timeout on Linux](https://partrobot.ai/blog/setting-keyboard-backlight-timeout-linux/).
*(Reference: [Arch Linux Wiki - Keyboard Backlight](https://wiki.archlinux.org/title/keyboard_backlight))*
