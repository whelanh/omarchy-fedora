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
| initramfs | mkinitcpio | `fedora/system/dracut/` | Yes — detect dracut vs mkinitcpio |
| bootloader | Limine | Fedora GRUB2/systemd-boot (not yet wired) | Partial |
| DKMS cleanup | kernel-modules-hook | akmods (not yet wired) | No — distro-specific |
| update guard | libalpm hook | dropped (no dnf analog) | No |
| firewall | UFW | firewalld (decision pending) | No |

No files inside `upstream/` are currently modified by this repo.
