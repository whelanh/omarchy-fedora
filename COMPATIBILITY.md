# COMPATIBILITY

Complete dependency/package status of Omarchy Quattro on Fedora.

Target: **Fedora Rawhide / recent stable, x86_64, systemd, Wayland.**

The authoritative source is `fedora/mappings/packages.yaml`; this document is a
human-readable summary. Classifications:

- `FEDORA_OFFICIAL` — in Fedora official repos
- `FEDORA_COPR` — via a COPR repository
- `FEDORA_RPMFUSION` — via RPM Fusion
- `FEDORA_FLATPAK` — best via Flathub
- `FEDORA_SUBSTITUTE` — same functionality, different package name
- `FEDORA_EXTERNAL` — via an upstream non-COPR RPM repo (e.g. mise)
- `FIRST_PARTY` — Omarchy first-party, shipped as RPMs from `whelanh/omarchy` COPR
- `NOT_AVAILABLE` — no reasonable Fedora equivalent
- `NOT_REQUIRED` — Arch-only tooling to drop

## Source of truth for the mapping

`fedora/scripts/lib/resolve.py --source <x>` prints the Fedora package names
for each classification. Static tests verify every upstream base package is
mapped.

## Summary counts (from packages.yaml, 199 entries)

| Classification | ~Count |
|---|---|
| fedora (official) | ~120 |
| substitute | ~30 |
| copr | ~11 + 10 first-party |
| external (mise) | 1 |
| unavailable | ~19 |
| drop (Arch-only) | ~8 |
| rpmfusion | ~8 |
| flatpak | 1 |

## Notable decisions (not mechanical renames)

### Hyprland ecosystem (COPR: `nett00n/hyprland`)
Fedora Rawhide ships `hyprland` and `quickshell` in official repos. The rest of
the desktop ecosystem — `hyprland-guiutils`, `hyprpicker`, `hyprsunset`,
`uwsm`, `xdg-desktop-portal-hyprland`, `gtk4-layer-shell` — comes from the
actively-maintained `nett00n/hyprland` COPR. `solopasha/hyprland` is no longer
actively maintained (as of 2026).

### NVIDIA (RPM Fusion nonfree)
Arch's `nvidia-*-dkms` + `nvidia-utils` map to Fedora's `akmod-nvidia` +
`xorg-x11-drv-nvidia` from RPM Fusion nonfree. Fedora uses `akmods`, not
`kernel-modules-hook`.

### Boot / kernel
Arch's custom kernels (`linux-ptl`, `linux-t2`) and `linux-headers` have no
direct analog: Fedora uses the stock `kernel` and `kernel-devel`. Limine and
mkinitcpio are replaced by Fedora's GRUB2/systemd-boot and dracut.

### mise (external RPM repo)
Arch's `mise-bin` maps to the Fedora binary `mise`, but mise is **not** in
Fedora official repos (a `packages.fedoraproject.org` lookup returns 404 for
both `mise` and `mise-bin`). Omarchy's `omarchy-default-agent` (shell menu →
"install an opening agent" like opencode/claude) and `omarchy-install-dev-env`
both drive everything through `mise use -g`, so it must be present. It ships
from the upstream mise RPM repo (`https://mise.jdx.dev/rpm/mise.repo`, signed,
gpgcheck=1) enabled by the installer via `dnf config-manager --add-repo`. See
`fedora/mappings/repositories.yaml` (entry `mise`).

### First-party Omarchy binaries (FIRST_PARTY, COPR `whelanh/omarchy`)
10 Omarchy packages (`aether`, `cliamp`, `herdr`, `hyprland-preview-share-picker`,
`omacalc`, `omacut`, `omawrite`, `tensaku`, `tobi-try → try`, `ttfx`) are
source-built or repacked as Fedora RPMs. Specs live in `fedora/rpm/` (one SPEC
per package) with a `manifest.yaml` (repo, build system, license, status) and
publish tooling in `fedora/rpm/copr/`.

**Status — 10 verified, 0 blocked.** Every package builds cleanly in a Fedora
Rawhide container and is published from the `whelanh/omarchy` COPR. The
default installer enables that COPR and installs the set (disable with
`install.sh --no-firstparty`).

| Package | Version | Notes |
|---------|---------|-------|
| aether | v4.29.8 | Go/Wails, repacked release binary |
| cliamp  | v1.63.2 | Go/CGO, repacked release binary |
| herdr   | v0.8.2 | Rust, repacked release binary (herdrdev/herdr) |
| hyprland-preview-share-picker | v0.2.1 | Rust/GTK4, source-built |
| omacalc | v0.2.2 | Qt6/qmake6 |
| omacut  | v0.4.0 | Qt6/qmake6 + ffmpeg |
| omawrite| v0.5.0 | Qt6/qmake6 |
| tensaku | v0.28.0 | repacked release tarball (GTK4) |
| try (tobi-try) | v1.10.1 | Ruby gem |
| ttfx    | v0.3.2 | pure Rust/cargo |

Dropped from RPM scope (were in the original 13): `asdcontrol` (archived
upstream, Apple-display-only), `omarchy-nvim` (in-tree LazyVim cache
assembly), and `usage` (already shipped in-tree by the base install — an RPM
would file-conflict). Rationale in `fedora/rpm/README.md`.
`hyprland-preview-share-picker` needs `gtk4-layer-shell-devel`, which the
COPR pulls from the `nett00n/hyprland` build repo.

## Omarchy CLI / plugin commands on Fedora

The `omarchy` CLI (including `omarchy plugin add/enable/list/update`, `omarchy
theme`, `omarchy capture`, etc.) is **distro-neutral**: the `omarchy-*` scripts
depend only on `git`, `jq`, `gum`, `git-delta` (pager) and the live Quickshell
session — no package manager. The installer wires them onto PATH by symlinking
`bin/omarchy-*` → `/usr/bin/omarchy-*` and installing
`/etc/profile.d/omarchy.sh` (which sources the upstream env-bootstrap to set
`OMARCHY_PATH=/usr/share/omarchy`).

Caveats:
- `omarchy plugin enable/disable` talk to the running shell via
  `omarchy-shell shell enablePlugin`, so Quickshell must be running.
- The 10 first-party binary packages are built and published from the
  `whelanh/omarchy` COPR and installed by the default installer
  (`--no-firstparty` to skip); all are `verified` in `fedora/rpm/manifest.yaml`.
- `gum` and `git-delta` were added to `fedora/packages/base.txt` as
  dependencies of the CLI layer.

## Known incompatibilities / open work

1. **First-party RPM packaging (done)** — 10 Omarchy binaries built + published
   from the `whelanh/omarchy` COPR (`fedora/rpm/`, see `fedora/rpm/copr/`).
   Installed by the default installer. CI re-verifies the specs on push.
2. **libalpm hooks / "update guard"** — Arch's pacman PreTransaction guard that
   forces updates through `omarchy update` has no dnf equivalent; dropped.
3. **UFW vs firewalld** — upstream default firewall is UFW. Fedora defaults to
   firewalld; the MVP does not yet configure the firewall (both are available;
   a decision is pending).
4. **PAM/authselect** — upstream edits `/etc/pam.d/system-auth` and
   `/etc/pam.d/sddm`; on Fedora this must go through `authselect`, not direct
   file edits. Addressed in Phase 6 (not yet in installer).
5. **snapper boot-menu sync** — upstream uses `limine-snapper-sync`; on Fedora
   this needs a GRUB snapper plugin. Not yet wired.
6. **Session/display manager** — SDDM is available on Fedora and used, but the
   wayland-session entry and Hyprland greeter config need Fedora packaging.

## Requirement: no security bypass

The port does **not** disable SELinux, systemd security, or the firewall to
work around incompatibilities. Any proposed bypass is rejected.
