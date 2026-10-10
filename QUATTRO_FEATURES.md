# QUATTRO_FEATURES

Omarchy Quattro feature compatibility matrix on Fedora.

Status legend: `PASS` working, `PARTIAL`, `TODO`, `N/A` not applicable /
out of scope.

| Feature | Upstream Quattro | Fedora | Status | Notes |
|---|---|---|---|---|
| Hyprland | yes | yes | PASS | installed (official Rawhide); needs session/driver validation in VM |
| Quickshell | yes | yes | PASS | installed (COPR/rawhide); shell integration pending |
| Omarchy CLI | yes | yes | PASS | first-party binaries/plugins packaged in the `whelanh/omarchy` COPR (20 verified) |
| Themes | yes | yes | PASS | config tree copied |
| Web apps | yes | yes | PASS | |
| Notifications | yes |yes | PASS | |
| Audio | yes | yes | PASS | PipeWire present; tuning pending |
| Bluetooth | yes | yes | PASS | bluetooth.service enabled |
| Screenshots | yes | yes  | PASS | Normal PrtScrn hot key |
| System updates | yes | yes | PASS | omarchy update |
| Snapshots | yes | yes  | PASS | pre & postsnapper present; grub-btrfs enabled |
| Session (SDDM/Wayland) | yes | yes | PASS | |
| File manager | yes | yes | PASS | nautilus installed |
| Terminal | yes | yes | PASS | foot installed |
| Launcher/menu | yes | yes | PASS | |

## Target

The goal is **feature parity**, not merely "Hyprland starts."

## Validation workflow

Fill rows in via fedora VM testing (`fedora/tests/`) before marking `PASS`.
See `docs/ARCH_SPECIFIC_INVENTORY.md` and `TROUBLESHOOTING.md`.
