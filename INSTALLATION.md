# INSTALLATION

## Supported target

- Fedora **Rawhide** (or recent stable), **x86_64**
- systemd
- Wayland-capable hardware

Not yet: Fedora Atomic / Silverblue / Kinoite / Asahi / ARM / immutable
variants.

## Prerequisites

- A fresh or clean Fedora installation (Workstation recommended)
- Network access
- Root or sudo
- ~4 GB free disk space

## 1. Get the repo

```bash
git clone https://github.com/whelanh/omarchy-fedora.git
cd omarchy-fedora
```

## 2. (Optional) static validation

```bash
bash fedora/tests/static.sh
```

## 3. Bootstrap (recommended on minimal installs)

Ensures network + development tools:

```bash
sudo ./fedora/scripts/bootstrap.sh
```

## 4. Install

```bash
sudo ./fedora/scripts/install.sh
```

The installer is **idempotent** — re-running is safe.

Options:

```bash
sudo ./fedora/scripts/install.sh --dry-run   # check only, no changes
sudo ./fedora/scripts/install.sh --no-omarchy # deps/system only
sudo ./fedora/scripts/install.sh --user bob    # configure files for bob
sudo ./fedora/scripts/install.sh --nvidia      # also enable RPM Fusion + NVIDIA
```

## 5. Reboot

```bash
sudo systemctl reboot
```

On reboot, select the Omarchy session at the display manager.

> **Note:** Omarchy first-party binaries (aether, asdcontrol, cliamp, herdr,
> omacalc, omacut, omawrite, omarchy-nvim, tensaku, ttfx, usage) are not yet
> packaged for Fedora. The desktop/config tree is installed, but those CLI/GUI
> commands are not yet available. See COMPATIBILITY.md.
