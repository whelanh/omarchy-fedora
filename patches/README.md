# Patches

This directory documents every Fedora-specific modification to upstream code.
The project's goal is to **shrink** this set over time by contributing fixes
upstream.

This project vendors upstream via git subtree and stages Fedora changes in
`fedora/`, so most "patches" are really Fedora-layer implementations rather
than edits inside `upstream/`. Anything that genuinely modifies a file inside
`upstream/` must be documented here.

## Template

```text
Patch:
Reason:
Affected upstream files:
Can this be upstreamed?:
Upstream issue/PR:
Expected removal condition:
```

## Current Fedora-layer adaptations (not upstream edits)

| Area | Upstream mechanism | Fedora implementation | Can be upstreamed? |
|---|---|---|---|
| package manager | `pacman`/`yay` (`omarchy-pkg-*`) | `fedora/scripts/lib/pkg.sh` (`omarchy_pkg_*` on dnf/rpm) | Yes — a distro-neutral `omarchy_pkg_*` abstraction |
| `omarchy-pkg-*` commands (add/drop/missing/present/install/remove/aur-*) | pacman/yay wrappers vendored under `upstream/bin/` | install-time shims written by `install.sh` (`install_omarchy_pkg_shims`) that source `pkg.sh` and dispatch to `omarchy_pkg_*`; leaves `upstream/` untouched | Yes — upstream `omarchy_pkg_*` abstraction would remove the shims entirely |
| initramfs | mkinitcpio | `fedora/system/dracut/` | Yes — detect dracut vs mkinitcpio |
| bootloader | Limine | Fedora GRUB2/systemd-boot (not yet wired) | Partial |
| DKMS cleanup | kernel-modules-hook | akmods (not yet wired) | No — distro-specific |
| update guard | libalpm hook | dropped (no dnf analog) | No |
| firewall | UFW | firewalld (decision pending) | No |

No files inside `upstream/` are currently modified by this repo.
