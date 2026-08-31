# ARCH_SPECIFIC_INVENTORY.md

Arch-specific assumptions found in upstream Omarchy Quattro.

- Upstream repo: https://github.com/omacom/omarchy
- Branch: `quattro`
- Upstream version: `4.0.0.alpha`
- Upstream HEAD analyzed: `b686ed89`
- Analysis date: 2026-08-31

This inventory was produced in Phase 1 (reconnaissance) and drives every
subsequent Fedora compatibility decision. It is a living document; update it
as the port evolves.

---

## 1. Package manager surface

Omarchy funnels package installation through a thin command layer that is
hard-wired to Arch. There is **no pluggable distro backend**.

### Primary abstraction functions (these are the single choke points)

| File | Function | Arch command | Fedora replacement |
|---|---|---|---|
| `bin/omarchy-pkg-add` | install if missing | `pacman -S --noconfirm --needed`, post-check `pacman -Q` | `dnf -y install` + `rpm -q` |
| `bin/omarchy-pkg-missing` | true if any pkg absent | `pacman -Q` | `rpm -q` (per-package check) |
| `bin/omarchy-pkg-present` | true if all pkgs present | `pacman -Q` | `rpm -q` |
| `bin/omarchy-pkg-drop` | remove if installed | `pacman -Qq` + `pacman -Rns` | `rpm -q` + `dnf -y remove` |
| `bin/omarchy-pkg-install` | fzf TUI to install | `pacman -Slq` / `pacman -Sii` / `pacman -S` | `dnf repoquery` / `dnf info` / `dnf install` |
| `bin/omarchy-pkg-remove` | fzf TUI to remove | `yay -Qqe` / `yay -Qi` / `pacman -Rns` | `dnf list installed` / `dnf remove` |

### AUR-specific (no Fedora analog)

| File | Function | Note |
|---|---|---|
| `bin/omarchy-pkg-aur-accessible` | curl `aur.archlinux.org` | replace with COPR reachability |
| `bin/omarchy-pkg-aur-add` | `yay -S --noconfirm --needed` | map to COPR/Flathub or drop |
| `bin/omarchy-pkg-aur-install` | `yay -Slqa` TUI | no Fedora analog |

`omarchy-pkg-add` is called from ~50 install/remove scripts. Retargeting it
(plus `-missing` / `-present` / `-drop`) covers most of the port.

---

## 2. The `omarchy update` pipeline

`bin/omarchy-update` orchestrates:

1. `omarchy-update-dev` (git checkout, dev channel)
2. `omarchy-update-keyring` — `pacman-key`, `archlinux-keyring`, omarchy-keyring
3. `omarchy-update-system-pkgs` — `pacman -Syu --overwrite '/usr/share/omarchy/*'`
4. `omarchy-migrate` — runs `migrations/`
5. `omarchy-hook post-update`
6. `omarchy-update-aur-pkgs` — `yay -Sua`
7. `omarchy-update-mise`
8. `omarchy-update-orphan-pkgs` — `pacman -Qtdq`, `pacman -Rns`

Fedora replacements needed for the update commands:

| Command | Arch | Fedora |
|---|---|---|
| `omarchy-update-system-pkgs` | `pacman -Syu` | `dnf -y upgrade` |
| `omarchy-update-keyring` | `pacman-key` | Fedora GPG keys + COPR repo keys |
| `omarchy-update-aur-pkgs` | `yay`/AUR | drop or route to COPR/Flathub |
| `omarchy-update-orphan-pkgs` | `pacman -Qtdq` | `dnf autoremove` / package-cleanup |
| `omarchy-update-pkg-prune` | `paccache -rk2` | dnf cache management |
| `omarchy-update-available` | `checkupdates`, `pacman -Q` | `dnf check-update`, `rpm -q` |
| `omarchy-update-pacman-guard` + libalpm hook | libalpm PreTransaction | no dnf analog; drop or dnf plugin |
| `omarchy-refresh-pacman` | `/etc/pacman.conf` + mirrorlist | `/etc/yum.repos.d/` omarchy repo |
| `omarchy-update-firmware` | `/boot/EFI/arch/` path | `/boot/EFI/fedora/` |

---

## 3. System-level integration

### mkinitcpio → dracut (initramfs)

Writes `/etc/mkinitcpio.conf.d/*.conf` (6 install files, 6+ bin/migration files):

- `etc/mkinitcpio.conf.d/omarchy_hooks.conf`
- `etc/mkinitcpio.conf.d/thunderbolt_module.conf`
- `install/hardware/nvidia.sh`
- `install/hardware/fix-surface-keyboard.sh`
- `install/hardware/apple/fix-t2.sh`, `fix-spi-keyboard.sh`
- `bin/omarchy-hibernation-*`, `omarchy-plymouth-set`, `omarchy-provision-owner`, `omarchy-system-factory-reset`, `omarchy-upgrade-to-quattro`

Fedora equivalent: **dracut** — `/etc/dracut.conf.d/` drop-ins,
`force_drivers`/`add_drivers`, `install_items`, `dracut --regenerate-all`.

### Bootloader: Limine → GRUB2/systemd-boot

- `etc/limine-entry-tool.d/` (omarchy-defaults.conf, omarchy-uki.conf)
- `default/limine/`
- `default/snapper/root` + `limine-snapper-sync`

Fedora default is **GRUB2 with BLS** or systemd-boot + kernel-install. UKI
via `dracut --uefi`.

### Package DB / signing

- `pacman.conf` / `pacman.d/mirrorlist` / libalpm / pacman-key / `[omarchy]` repo
- `var-cache-pacman-pkg.mount` (provisioning service orders against it)

Fedora: rpm + DNF + COPR; GPG verification via repo `gpgkey`.

### Snapper / btrfs

- `default/snapper/root`, `install/config/snapper.sh`, `limine-snapper-sync`
- btrfs default (already default on Fedora Workstation)

snapper is available on Fedora; boot-menu snapshot sync needs the GRUB
snapper plugin instead of limine-snapper-sync.

### DKMS kernel module cleanup

- `linux-modules-cleanup.service` (from `kernel-modules-hook`)
- enabled in `install/config/enable-services.sh`

Fedora: **akmods** (`akmods.service`).

### PAM / security

- `install/config/increase-lockout-limit.sh` (edits `/etc/pam.d/system-auth`)
- `etc/security/faillock.conf`
- `etc/nsswitch.conf` (full-file override)

Fedora uses **authselect**. Do not clobber system files.

### Firewall

- UFW + ufw-docker (`install/config/firewall.sh`)

Fedora default is **firewalld**. Must adapt (ship UFW as RPM, or re-express
rules for firewalld).

---

## 4. Package list (Arch → Fedora status)

The full package list lives in `install/omarchy-base.packages` (149 pkgs) and
`install/omarchy-other.packages` (~60 pkgs). The Fedora mapping is maintained
in `fedora/mappings/packages.yaml`.

Categories:

- **FEDORA_OFFICIAL**: ripgrep, jq, fd, fzf, bat, btop, git, docker, etc.
- **COPR / rpmfusion**: hyprland (now FEDORA_OFFICIAL in Rawhide), quickshell,
  uwsm, sddm, gpu-screen-recorder, nerd fonts, nvidia drivers, etc.
- **FLATPAK**: obsidian, localsend (some have native/Deb too), etc.
- **NOT_AVAILABLE / needs build**: omacalc, omacut, omawrite, aether,
  asdcontrol, cliamp, herdr, tensaku, ttfx, tobi-try, usage, omarchy-nvim —
  Omarchy-first-party packages must be rebuilt from source as RPMs.

**Arch-only tools to drop**: `expac`, `pacman-contrib`, `fakeroot` (build
only), `yay` / `yay-debug`, `base` / `base-devel` (replace with Fedora
`@development-tools`), `linux-*` custom kernels, `limine-*`.

---

## 5. Packages with no direct package-manager call

Many install/config/user scripts do systemd, config-file, or user-data work
only (no pacman/dnf). These are portable with path / unit-name adjustments:
user scripts (git, xcompose, keyring), most ssh/cups/systemd config, and the
majority of `migrations/` (pure systemctl/config edits).

---

## 6. Cross-distro signals

Only `flatpak` is used as an additional manager — it is portable and should be
kept (native installation preferred, Flatpak as fallback for GUI apps
unavailable on Fedora).
