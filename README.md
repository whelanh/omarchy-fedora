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

> **IN DEVELOPMENT.** This is the initial scaffold. The installer
> (`fedora/scripts/install.sh`) and package mapping exist and pass static
> tests, but have not yet been validated on a live Fedora system. See
> `docs/ARCH_SPECIFIC_INVENTORY.md` and `QUATTRO_FEATURES.md` for what is
> done and what remains.

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

> Note: Omarchy's first-party packages (aether, asdcontrol, cliamp, herdr,
> omacalc, omacut, omawrite, omarchy-nvim, tensaku, ttfx, usage) must still be
> built as Fedora RPMs (`BUILD_FROM_SOURCE`). The installer installs the
> vendored desktop tree but not yet those binaries.

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
