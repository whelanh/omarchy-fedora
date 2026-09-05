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
subtree and stays authoritative. **This is not an independent fork of
Omarchy.**

---

## Status

> **IN DEVELOPMENT.** This has been successfully run on VirtManager VMs
> that start with the latest nightly Fedora Sway Rawhide image.  It has
> also been successfully deployed on an Asus ROG laptop (also starting from
> Fedora Sway Rawhide system).  Most/many features work and
> the Super keys act as expected.  The update process has also been
> tested.  However, there are no doubt still some
> things to be ironed out.  Bug reports are welcome.

<img width="1267" height="790" alt="screenshot-2026-09-02_12-59-51" src="https://github.com/user-attachments/assets/9e159b6e-e4f6-401c-8eaf-4c9fc7a546e7" />
<img width="1273" height="790" alt="screenshot-2026-09-02_12-54-14" src="https://github.com/user-attachments/assets/ac7628ed-43a5-4a23-b6a5-a9b1dc451a22" />
<img width="1257" height="787" alt="screenshot-2026-09-02_12-53-20" src="https://github.com/user-attachments/assets/21a8025e-a1e6-4c9c-be45-7585eb118344" />

## Supported target

- Fedora Rawhide / recent stable, **x86_64**
- systemd
- Wayland-capable hardware

Not yet supported: Fedora Atomic / Silverblue / Kinoite, Asahi, ARM, immutable
variants.

## Layout

```
fedora/
  packages/       Fedora package manifests (base, desktop, applications, optional)
  mappings/       packages.yaml (Arch->Fedora) and repositories.yaml (COPR/rpmfusion)
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
git clone git@github.com:whelanh/omarchy-fedora.git
cd omarchy-fedora

# Static validation (no system changes):
bash fedora/tests/static.sh

# Bootstrap (optional on a minimal install), then install:
sudo ./fedora/scripts/bootstrap.sh
sudo ./fedora/scripts/install.sh
sudo systemctl reboot
```

The installer is **idempotent** — running it again is safe.

> Note: Omarchy's first-party binaries (aether, cliamp, herdr,
> hyprland-preview-share-picker, omacalc, omacut, omawrite, tensaku, try, ttfx)
> are built as Fedora RPMs and installed from the `whelanh/omarchy` COPR by the
> installer (see `fedora/rpm/copr/README.md`). Pass `--no-firstparty` to skip.

## Rollback
In an attempt to emulate Omarchy's Limine rollback structure. The install script installs `snapper`, `btrfs-assistant`, and `grub-btrfs` (from COPR).  Snapshots are created pre and post upgrade and on a time-line (with retention limits). You can boot into a snapshot.  To actually re-set to a snapshot, follow directions for `snapper`.

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

## License

The Fedora compatibility layer is MIT licensed. Upstream Omarchy is MIT
licensed; see `upstream/LICENSE`. All upstream copyright/license information is
preserved.
