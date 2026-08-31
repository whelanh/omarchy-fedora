# ARCHITECTURE

## Goal

Provide the Omarchy Quattro desktop on Fedora as a **thin, continuously
synchronizing adapter** over the authoritative upstream `omacom/omarchy`
`quattro` branch — never as an independent fork with duplicated desktop code.

```
                 omacom/omarchy (quattro)  <-- authoritative
                          |
             git subtree vendor (upstream/)
                          |
              +-----------+-----------+
              |                       |
            Arch                    Fedora (this repo: fedora/)
              |                       |
         pacman/AUR              dnf/RPM/COPR
```

## What this repo adds on top of upstream

Only the Fedora-specific problems are solved here:

- package acquisition + naming (dnf vs pacman)
- repository / COPR / RPM Fusion configuration
- Fedora system integration (dracut initramfs, systemd, udev, sysctl)
- Fedora install/bootstrap
- Fedora testing
- incompatibilities that cannot reasonably be eliminated upstream

## Vendoring model (Phase 8, spec section 11)

Preferred model chosen: **git subtree**.

- `upstream/` is a squashed subtree of `omacom/omarchy` `quattro`.
- `git subtree pull --prefix upstream upstream quattro` refreshes it.
- Keeping upstream separate from `fedora/` prevents divergence and makes diffs
  visible: `git diff fedora..upstream/quattro`.

## Package abstraction

`fedora/scripts/lib/pkg.sh` implements the semantic package API, so the Fedora
layer never calls `dnf` directly throughout:

```
omarchy_pkg_install        dnf install -y
omarchy_pkg_remove         dnf remove -y
omarchy_pkg_update         dnf makecache
omarchy_pkg_upgrade        dnf upgrade -y
omarchy_pkg_is_installed   rpm -q
omarchy_pkg_install_file   dnf install <file.rpm>
omarchy_pkg_enable_repo    dnf copr enable / repo file drop
omarchy_pkg_query          dnf info / rpm -qa
```

This mirrors the upstream intent of an `omarchy_pkg_*` abstraction, which on
Arch is currently a thin pacman wrapper.

## Mapping

`fedora/mappings/packages.yaml` declares Arch→Fedora for every upstream package
with a source classification (`fedora`, `copr`, `rpmfusion`, `flatpak`,
`substitute`, `build`, `drop`, `unavailable`). `fedora/scripts/lib/resolve.py`
reads it. `fedora/mappings/repositories.yaml` documents every external repo.

## System integration differences (Phase 6)

| Arch | Fedora |
|------|--------|
| pacman / yay / AUR | dnf / rpm / COPR / Flathub |
| mkinitcpio initramfs | dracut |
| Limine bootloader | GRUB2 (BLS) / systemd-boot |
| libalpm hooks | dnf plugins / rpm scriptlets |
| kernel-modules-hook | akmods |
| snapper + limine-snapper-sync | snapper + GRUB plugin |
| UFW | firewalld (or UFW packaged) |
| SDDM + Hyprland greeter | SDDM (portable) |

See `docs/ARCH_SPECIFIC_INVENTORY.md` for the full file-level inventory.

## Fail-closed rules

- No disabling SELinux, systemd security, or the firewall to make things work.
- No `chmod 777`, no running everything as root.
- Every external repository is documented and gpg-verified.
- No piping untrusted remote content into `bash`/`sh`.

## Decision workflow for upstream changes

1. New upstream change detected (upstream-sync workflow).
2. Classify: SAFE / FEDORA_RELEVANT / CONFLICT / NEW_DEPENDENCY /
   SYSTEM_INTEGRATION_CHANGE / MANUAL_REVIEW_REQUIRED.
3. SAFE → merge automatically. FEDORA_RELEVANT → update mapping + test.
4. Anything touching a Fedora-patched area → stop, manual review.
