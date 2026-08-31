# QUATTRO_FEATURES

Omarchy Quattro feature compatibility matrix on Fedora.

Status legend: `PASS` working, `PARTIAL`, `TODO`, `N/A` not applicable /
out of scope.

| Feature | Upstream Quattro | Fedora | Status | Notes |
|---|---|---|---|---|
| Hyprland | yes | yes | PARTIAL | installed (official Rawhide); needs session/driver validation in VM |
| Quickshell | yes | yes | PARTIAL | installed (COPR/rawhide); shell integration pending |
| Omarchy CLI | yes |  | TODO | first-party binaries not yet packaged |
| Themes | yes |  | TODO | config tree copied; theme engine needs settings package |
| Web apps | yes |  | TODO | |
| Notifications | yes |  | TODO | |
| Audio | yes |  | TODO | PipeWire present; tuning pending |
| Bluetooth | yes |  | TODO | bluetooth.service enabled |
| Screenshots | yes |  | TODO | |
| System updates | yes |  | TODO | dnf-based updater scaffolded (fedora/scripts/update.sh) |
| Snapshots | yes |  | TODO | snapper present; btrfs boot-sync pending |
| Session (SDDM/Wayland) | yes |  | TODO | |
| File manager | yes | PARTIAL | nautilus installed |
| Terminal | yes | PARTIAL | foot installed |
| Launcher/menu | yes |  | TODO | |

## Target

The goal is **feature parity**, not merely "Hyprland starts."

## Validation workflow

Fill rows in via fedora VM testing (`fedora/tests/`) before marking `PASS`.
See `docs/ARCH_SPECIFIC_INVENTORY.md` and `TROUBLESHOOTING.md`.
