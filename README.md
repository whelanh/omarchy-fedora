# Omarchy Fedora

> This is a Fedora compatibility implementation of Omarchy Quattro. The
> upstream Omarchy repository remains authoritative for the desktop experience.

**Omarchy Fedora** is a thin Fedora adapter for
[Omarchy Quattro](https://github.com/omacom/omarchy) (branch `quattro`). It
provides the Omarchy desktop experience on Fedora by solving the Fedora-side
problems — package acquisition, naming differences, repository/COPR
configuration, system integration, initramfs, and installation — while keeping
the desktop/configuration code driven by upstream.

The upstream Omarchy tree is vendored under [`upstream/`](upstream) via git
subtree and stays authoritative. **This is not intended as an independent fork of
Omarchy -- it is meant to duplicate the Omarchy experience as closely as possible
.**

This has been sucessfully deployed in Fedora Rawhide, Fedora 44 and Fedora 45.  Omarchy "1st party" packages are available in the COPR repo for all three Fedora versions.

---

## Status

> **IN DEVELOPMENT.**  Bug reports are welcome.

<img width="1267" height="790" alt="screenshot-2026-09-02_12-59-51" src="https://github.com/user-attachments/assets/9e159b6e-e4f6-401c-8eaf-4c9fc7a546e7" />
<img width="1273" height="790" alt="screenshot-2026-09-02_12-54-14" src="https://github.com/user-attachments/assets/ac7628ed-43a5-4a23-b6a5-a9b1dc451a22" />
<img width="1257" height="787" alt="screenshot-2026-09-02_12-53-20" src="https://github.com/user-attachments/assets/21a8025e-a1e6-4c9c-be45-7585eb118344" />

## Supported target

- Fedora Rawhide, 44 or 45 **x86_64** (starting with Fedora Sway spin recommended, although KDE is also a good starting point)

## Layout

```
fedora/
  packages/       Fedora package manifests (base, desktop, applications, optional)
  mappings/       packages.yaml (Arch->Fedora), repositories.yaml (COPR/rpmfusion),
                  retired-packages.conf and package-audit-baseline.conf
  system/         systemd, sysctl, udev, dracut configs
  scripts/        bootstrap.sh, install.sh, update.sh, uninstall.sh, lib/
  tests/          static + VM test suites
patches/          Fedora-specific patches against upstream (documented)
upstream/         vendored upstream Omarchy quattro (via git subtree)
docs/             reconnaissance inventory and engineering notes
```

## Quick start (MVP)

```bash
# On a fresh Fedora system:
git clone https://github.com/whelanh/omarchy-fedora.git
cd omarchy-fedora

# Static validation (no system changes):
bash fedora/tests/static.sh

# Bootstrap (optional on a minimal install), then install:
sudo ./fedora/scripts/bootstrap.sh

# The --with-session-chooser flag installs an alternative 
# Omarchy SDDM theme that allows you to select a session at login.  
# Without this option, you won't be able to log back into 
# your original desktop environment.  
sudo ./fedora/scripts/install.sh --with-session-chooser

systemctl reboot
```

The installer is **idempotent** — running it again is safe.

> Note: Omarchy's first-party binaries and plugins (aether, cliamp, disktree-bin,
> gliff, herdr, hype, hyprland-preview-share-picker, monologue,
> omacalc, omacut, omapresent, omarchy-hyprland-titlebars,
> omarchy-local-ai, omarchy-screensaver, omawrite, omasnap, owe, owe-lockfeed,
> qtengine, signed, superwhisper-bin, try, ttfx) are built as Fedora RPMs and
> installed from the `whelanh/omarchy` COPR by the installer (see
> `fedora/rpm/copr/README.md`). Pass `--no-firstparty` to skip. `omarchy-emacs`,
> `openai-codex-desktop` and `voxtype-bin` are published there for on-demand
> install from the menu. (The `elsewhen` world-clock plugin is retired: upstream
> moved it in-tree as `omarchy.elsewhen`. The Codex CLI is retired from RPM:
> upstream installs it via mise. `tensaku` is retired: upstream replaced it with
> `omasnap`.)

## Login screen

**Default (Omarchy only).** The stock Omarchy SDDM greeter is deliberately
minimal — a logo, a lock icon and a password box. It reads the username from
`/var/lib/sddm/state.conf` and logs straight into Omarchy; there is no session
picker. On a machine converted from KDE, Sway or GNOME that is a one-way door:
once you log out there is no way back to the desktop you came from.

**`--with-session-chooser`.** Pass the flag to `install.sh` (also shown in
[Quick start](#quick-start-mvp)) to install the opt-in **omarchy-plus** theme
instead: the same look, plus a session picker and an editable username field. It
installs *alongside* the stock theme, leaves it untouched, and points SDDM at
the new one with a single drop-in. Revert with `--without-session-chooser`, or by
re-running the installer with no flag:

```bash
sudo ./fedora/scripts/install.sh --with-session-chooser   # opt in
sudo ./fedora/scripts/install.sh                          # back to stock
```

**Already installed? (`enable-session-chooser.sh`).** Installs made *before* the
flag existed have the stock greeter, so the choice is unreachable. Opt in once,
by hand:

```bash
cd omarchy-fedora        # your checkout, updated (git pull, or omarchy update)
sudo ./fedora/scripts/enable-session-chooser.sh
```

That script publishes the omarchy-plus theme, selects it, and **turns SDDM
autologin off** — while autologin is on, the machine logs straight into Omarchy
and the greeter never appears, so the chooser cannot be reached at boot. It is
safe to re-run, takes effect at the next login or reboot (it never restarts
SDDM, which would end your session), and records the choice so `omarchy update`
keeps it. Undo with `sudo ./fedora/scripts/install.sh` and restore
`/etc/sddm.conf.omarchy-session-chooser.bak` if your autologin was changed.

See [`fedora/sddm-omarchy-plus/README.md`](fedora/sddm-omarchy-plus/README.md)
for the full details and the theme's maintenance contract.

## Update
This repo runs a daily workflow to keep it in line with upstream Omarchy.  Users can
run `omarchy update` from their terminal to update (it re-runs the installer after
doing a dnf upgrade).  You may occasionally get hyprland config errors during an update -- just
let the update complete and then reboot.

## Rollback
In an attempt to emulate Omarchy's Limine rollback structure, the install script sets up `snapper`, `btrfs-assistant` and `grub-btrfs` (from COPR) on btrfs systems.  Snapshots are created pre and post upgrade and on a time-line (with retention limits), and `grub-btrfs` lists them in the GRUB menu so you can boot one.  To actually re-set to a snapshot, follow directions for `snapper`, or use `btrfs-assistant`'s Snapper view to browse, diff and restore.

Note: when `/boot` is a separate (non-btrfs) filesystem -- Fedora's default layout -- kernels are not part of the snapshots, so a snapshot entry boots the kernel currently in `/boot` rather than the one it was taken with.  A snapshot from before a kernel update restores `/` only.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — design and upstream integration model
- [UPSTREAM.md](UPSTREAM.md) — how upstream stays authoritative
- [COMPATIBILITY.md](COMPATIBILITY.md) — complete package/dependency status
- [INSTALLATION.md](INSTALLATION.md)
- [TESTING.md](TESTING.md) — how to validate on a Fedora VirtManager VM
- [UPDATING.md](UPDATING.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- [QUATTRO_FEATURES.md](QUATTRO_FEATURES.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/ARCH_SPECIFIC_INVENTORY.md](docs/ARCH_SPECIFIC_INVENTORY.md)
- [fedora/sddm-omarchy-plus/README.md](fedora/sddm-omarchy-plus/README.md) — opt-in login session chooser

## Contributors

- [Hugh Whelan](https://github.com/whelanh) — project author and maintainer.
- [Lukas Dolzer](https://github.com/luke-29) — SDDM/login-screen installer fix and root-ownership hardening (#15, #16).

## License

The Fedora compatibility layer is MIT licensed. Upstream Omarchy is MIT
licensed; see `upstream/LICENSE`. All upstream copyright/license information is
preserved.
