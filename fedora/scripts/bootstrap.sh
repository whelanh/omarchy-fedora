#!/bin/bash
#
# Omarchy Quattro for Fedora - bootstrap
#
# Prepares a fresh Fedora installation (Workstation or minimal) for the
# Omarchy installer. This handles the bare-minimum system prerequisites that
# the interactive desktop installer assumes are present:
#   - dnf present and working
#   - network access (NetworkManager, a D-Bus/network stack)
#   - a non-root sudo-capable user
#   - development tools (needed to build Omarchy first-party RPMs later)
#
# After bootstrap completes, run ./install.sh.
#
# Idempotent. Safe to run multiple times.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/pkg.sh"

log()  { printf '\033[1;34m[omarchy-bootstrap] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[omarchy-bootstrap] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[omarchy-bootstrap] %s\033[0m\n' "$*" >&2; exit 1; }

[ -r /etc/os-release ] || die "no /etc/os-release"
. /etc/os-release
[ "$ID" = fedora ] || die "bootstrap targets Fedora (found ID=$ID)"

if (( EUID != 0 )) && ! sudo -n true 2>/dev/null && ! command -v sudo >/dev/null 2>&1; then
  die "need root or sudo for bootstrap"
fi

log "Bootstrap for Fedora ${VERSION_ID:-?} (${VARIANT_ID:-?})"

# Ensure a functioning network stack + base tooling.
log "Installing base prerequisite packages (NetworkManager, curl, git, crypto)..."
if ! omarchy_pkg_is_installed NetworkManager; then
  _omarchy_dnf install -y NetworkManager >/dev/null || die "failed to install NetworkManager"
fi

# Development tools for building Omarchy first-party RPMs later.
if ! rpm -q gcc >/dev/null 2>&1; then
  log "Installing @development-tools group..."
  _omarchy_dnf group install -y 'development-tools' >/dev/null \
    || _omarchy_dnf install -y gcc gcc-c++ make kernel-devel >/dev/null \
    || warn "could not install development tools"
fi

# Ensure network enabled (on minimal installs NetworkManager may be off).
if command -v systemctl >/dev/null 2>&1; then
  if (( EUID == 0 )); then
    systemctl enable --now NetworkManager >/dev/null 2>&1 || warn "could not enable NetworkManager"
  else
    sudo systemctl enable --now NetworkManager >/dev/null 2>&1 || warn "could not enable NetworkManager"
  fi
fi

log "Bootstrap complete. Run ./install.sh to install Omarchy Quattro."
