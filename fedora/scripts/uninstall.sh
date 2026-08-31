#!/bin/bash
#
# Omarchy Quattro for Fedora - uninstall
#
# Removes the packages and installed files added by the installer and returns
# the system toward a stock Fedora desktop. It does NOT remove pre-existing
# user data.
#
# WARNING: this is destructive to the Omarchy desktop configuration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/pkg.sh"

log()  { printf '\033[1;34m[omarchy-uninstall] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;31m[omarchy-uninstall] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[omarchy-uninstall] %s\033[0m\n' "$*" >&2; exit 1; }

if (( EUID != 0 )); then
  exec sudo "$0" "$@" || die "need root (or sudo) to uninstall"
fi

log "Removing Omarchy system files..."
rm -rf /usr/share/omarchy || true
rm -f /etc/sysctl.d/90-omarchy-file-watchers.conf /etc/sysctl.d/99-omarchy-sysctl.conf
rm -f /etc/dracut.conf.d/50-omarchy.conf
rm -f /etc/udev/rules.d/99-omarchy-framework16-qmk-hid.rules
systemctl daemon-reload >/dev/null 2>&1 || true

log "Removing Fedora packages installed for Omarchy (desktop + applications)..."
# Remove the Fedora desktop/app packages. Base system packages are left intact.
omarchy_pkg_remove sddm hyprland quickshell hyprpicker hyprsunset \
  hyprland-guiutils uwsm gtk4-layer-shell fcitx5 fcitx5-gtk fcitx5-qt \
  xdg-desktop-portal-hyprland 2>/dev/null || true

log "Uninstall complete. You may remove COPR repos manually:"
log "  dnf copr remove nett00n/hyprland"
log "  systemctl disable sddm.service"
