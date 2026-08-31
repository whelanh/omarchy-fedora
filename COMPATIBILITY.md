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
- `BUILD_FROM_SOURCE` — Omarchy first-party, must build RPM from source
- `NOT_AVAILABLE` — no reasonable Fedora equivalent
- `NOT_REQUIRED` — Arch-only tooling to drop

## Source of truth for the mapping

`fedora/scripts/lib/resolve.py --source <x>` prints the Fedora package names
for each classification. Static tests verify every upstream base package is
mapped.

## Summary counts (from packages.yaml, 206 entries)

| Classification | ~Count |
|---|---|
| fedora (official) | ~120 |
| substitute | ~30 |
| copr | ~11 |
| build (first-party) | 13 |
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

### First-party Omarchy binaries (BUILD_FROM_SOURCE)
13 Omarchy packages (`aether`, `asdcontrol`, `cliamp`, `herdr`,
`hyprland-preview-share-picker`, `omacalc`, `omacut`, `omawrite`,
`omarchy-nvim`, `tensaku`, `tobi-try`, `ttfx`, `usage`) must be rebuilt as
Fedora RPMs from their upstream sources. This is a discrete packaging effort.

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
- The 13 first-party binary packages remain `BUILD_FROM_SOURCE` (not yet
  packaged), so commands backed by those binaries are unavailable until that
  RPM effort lands.
- `gum` and `git-delta` were added to `fedora/packages/base.txt` as
  dependencies of the CLI layer.

## Known incompatibilities / open work

1. **First-party RPM packaging** — 13 Omarchy binaries not yet packaged for
   Fedora. The installer copies the desktop/config tree but can't yet provide
   these binaries.
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
