#!/bin/bash
#
# Omarchy Quattro for Fedora - installer
#
# Converts a supported Fedora installation (Workstation or minimal, x86_64,
# systemd, Wayland-capable) into an Omarchy Quattro desktop.
#
# This is the MVP deliverable (spec Phase 7). It is IDEMPOTENT: running it
# multiple times is safe.
#
# Current supported target:
#   Fedora Rawhide / recent stable, x86_64, systemd, Wayland-capable hardware
#
# Usage:
#   sudo ./install.sh                # install everything
#   sudo ./install.sh --no-omarchy   # install deps/system only (no desktop copy)
#   sudo ./install.sh --dry-run      # check prerequisites, make no changes
#   sudo ./install.sh --user USER    # configure user files for USER

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UPSTREAM="$OMARCHY_ROOT/upstream"

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
COPY_OMARCHY=1
DRY_RUN=0
TARGET_USER=""
NVIDIA=0

for arg in "$@"; do
  case "$arg" in
    --no-omarchy) COPY_OMARCHY=0 ;;
    --dry-run)    DRY_RUN=1 ;;
    --user)       TARGET_USER="__NEXT__" ;;
    --nvidia)     NVIDIA=1 ;;
    *)
      if [ "$TARGET_USER" = "__NEXT__" ]; then
        TARGET_USER="$arg"
      fi
      ;;
  esac
done

if [ "$TARGET_USER" = "__NEXT__" ]; then
  echo "error: --user requires a username" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '\033[1;34m[omarchy] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[omarchy] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[omarchy] %s\033[0m\n' "$*" >&2; exit 1; }

# Source the dnf abstraction + deps libraries.
. "$SCRIPT_DIR/lib/pkg.sh"
. "$SCRIPT_DIR/lib/deps.sh"

# ---------------------------------------------------------------------------
# Phase A - Prerequisite verification
# ---------------------------------------------------------------------------

verify_fedora() {
  [ -r /etc/os-release ] || die "no /etc/os-release"
  . /etc/os-release
  case "${ID:-}" in
    fedora) ;;
    *) die "This installer targets Fedora (found ID=$ID). Aborting." ;;
  esac
  log "Detected Fedora ${VERSION_ID:-?} ($VARIANT_ID) on ${ID_LIKE:-}"
}

verify_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) log "Architecture OK (x86_64)" ;;
    *) die "Unsupported architecture: $arch (x86_64 required for now)" ;;
  esac
}

verify_systemd() {
  command -v systemctl >/dev/null 2>&1 || die "systemd (systemctl) not found"
  log "systemd present (PID 1: $(ps -p 1 -o comm= 2>/dev/null || echo 'unknown'))"
}

verify_network() {
  if [ "$DRY_RUN" = 1 ]; then
    log "network check skipped (--dry-run)"
    return 0
  fi
  if ! (command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1); then
    warn "neither curl nor wget found; network will be exercised by dnf"
    return 0
  fi
  local host="copr.fedorainfracloud.org"
  if curl -fsS --max-time 10 -o /dev/null "https://$host" 2>/dev/null \
     || wget -q --spider --timeout=10 "https://$host" 2>/dev/null; then
    log "network reachable"
  else
    die "network check failed: could not reach $host"
  fi
}

verify_sudo() {
  if (( EUID == 0 )); then
    log "running as root (OK)"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    log "passwordless sudo available (OK)"
  elif command -v sudo >/dev/null 2>&1; then
    log "sudo available (password will be requested)"
  else
    die "need root or sudo to run the installer"
  fi
}

verify_disk() {
  local needed_mb=4096
  local avail_mb
  avail_mb="$(df -Pk / | awk 'NR==2 {print $4}' 2>/dev/null || echo 0)"
  avail_mb=$((avail_mb / 1024))
  if [ "$avail_mb" -lt "$needed_mb" ]; then
    die "insufficient disk space (${avail_mb} MB free, need >= ${needed_mb} MB)"
  fi
  log "disk OK (${avail_mb} MB free)"
}

verify_prereqs() {
  log "== Verifying prerequisites =="
  verify_fedora
  verify_arch
  verify_systemd
  verify_network
  verify_sudo
  verify_disk
  command -v dnf >/dev/null 2>&1 || die "dnf not found"
  log "== Prerequisites OK =="
}

# ---------------------------------------------------------------------------
# Phase B - Repositories
# ---------------------------------------------------------------------------

install_repos() {
  log "== Installing required repositories =="
  omarchy_fedora_enable_coprs || die "failed to enable COPR repositories"
  # gpu-screen-recorder is part of the desktop; enable its COPR.
  omarchy_fedora_enable_optional_coprs brycensranch/gpu-screen-recorder-git \
    || die "failed to enable gpu-screen-recorder COPR"
  if [ "$NVIDIA" = 1 ]; then
    omarchy_fedora_enable_rpmfusion || die "failed to enable RPM Fusion"
  fi
  log "repositories configured"
}

# ---------------------------------------------------------------------------
# Phase C - Packages
# ---------------------------------------------------------------------------

install_packages() {
  log "== Installing packages =="
  omarchy_fedora_install_base || die "base package installation failed"
  omarchy_fedora_install_desktop || die "desktop package installation failed"
  omarchy_fedora_install_applications || die "application package installation failed"
  log "packages installed"
}

# ---------------------------------------------------------------------------
# Phase D - System configuration (services, udev, sysctl, dracut)
# ---------------------------------------------------------------------------

install_systemd_units() {
  local src="$OMARCHY_ROOT/fedora/system/systemd"
  [ -d "$src" ] || return 0
  if (( EUID == 0 )); then
    cp -a "$src"/. /etc/systemd/system/ 2>/dev/null || true
  else
    sudo cp -a "$src"/. /etc/systemd/system/ 2>/dev/null || true
  fi
  _systemctl_daemon_reload
}

_systemctl_daemon_reload() {
  if (( EUID == 0 )); then systemctl daemon-reload; else sudo systemctl daemon-reload; fi
}

install_sysctl() {
  local src="$OMARCHY_ROOT/fedora/system/sysctl"
  [ -d "$src" ] && cp_system_files "$src" /etc/sysctl.d/
}

install_udev() {
  local src="$OMARCHY_ROOT/fedora/system/udev"
  [ -d "$src" ] && cp_system_files "$src" /etc/udev/rules.d/
  _reload_udev
}

install_dracut() {
  local src="$OMARCHY_ROOT/fedora/system/dracut"
  [ -d "$src" ] && cp_system_files "$src" /etc/dracut.conf.d/
}

cp_system_files() {
  local src="$1" dest="$2"
  if (( EUID == 0 )); then
    cp -a "$src"/. "$dest/"
  else
    sudo cp -a "$src"/. "$dest/"
  fi
}

_reload_udev() {
  if (( EUID == 0 )); then udevadm control --reload >/dev/null 2>&1 || true
  else sudo udevadm control --reload >/dev/null 2>&1 || true; fi
}

enable_services() {
  log "== Enabling system services =="
  local -a units=(cups.service avahi-daemon.service NetworkManager.service \
                  systemd-resolved.service power-profiles-daemon.service sddm.service)
  for u in "${units[@]}"; do
    if systemctl list-unit-files "$u" >/dev/null 2>&1; then
      _systemctl_enable "$u" || warn "could not enable $u"
    fi
  done
  _systemctl_enable --now systemd-oomd >/dev/null 2>&1 || true
  # Bluetooth
  _systemctl_enable --now bluetooth.service >/dev/null 2>&1 || true
}

_systemctl_enable() {
  if (( EUID == 0 )); then systemctl enable "$@"; else sudo systemctl enable "$@"; fi
}

# ---------------------------------------------------------------------------
# Phase E - Omarchy desktop (vendored upstream -> /usr/share/omarchy)
# ---------------------------------------------------------------------------

install_omarchy_tree() {
  [ "$COPY_OMARCHY" = 1 ] || { log "skipping Omarchy desktop copy (--no-omarchy)"; return 0; }
  [ -d "$UPSTREAM" ] || die "vendored upstream not found ($UPSTREAM)"

  log "== Installing Omarchy desktop tree =="
  local dest=/usr/share/omarchy
  if (( EUID == 0 )); then
    mkdir -p "$dest"
    cp -a "$UPSTREAM"/* "$dest/"
  else
    sudo mkdir -p "$dest"
    sudo cp -a "$UPSTREAM"/* "$dest/"
  fi
  log "Omarchy tree installed to $dest"
  log "NOTE: first-party binary packages (aether, asdcontrol, cliamp, herdr," \
       "omacalc, omacut, omawrite, omarchy-nvim, tensaku, ttfx, usage) must still" \
       "be built as Fedora RPMs (see fedora/packages and BUILD_FROM_SOURCE)."
}

# Import omarchy-* commands onto PATH, mirroring the upstream architecture's
# package map: bin/omarchy-* -> /usr/bin/omarchy-* (with symlinks kept under
# /usr/share/omarchy/bin). This is what makes `omarchy plugin`, `omarchy theme`,
# etc. callable on Fedora.
install_omarchy_bin() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local tree=/usr/share/omarchy/bin
  [ -d "$tree" ] || { warn "no bin dir at $tree; skipping CLI wiring"; return 0; }

  log "== Wiring omarchy-* commands onto PATH =="
  local cmd
  for cmd in "$tree"/omarchy-*; do
    [ -e "$cmd" ] || continue
    local base
    base="$(basename "$cmd")"
    # Replace any pre-existing symlink, never a real file.
    if [ -L "/usr/bin/$base" ]; then
      if (( EUID == 0 )); then rm -f "/usr/bin/$base"; else sudo rm -f "/usr/bin/$base"; fi
    fi
    if [ ! -e "/usr/bin/$base" ]; then
      if (( EUID == 0 )); then ln -s "$cmd" "/usr/bin/$base"; else sudo ln -s "$cmd" "/usr/bin/$base"; fi
    fi
  done
}

# Set OMARCHY_PATH for login shells by sourcing the upstream env-bootstrap from
# /etc/profile.d (system-wide), mirroring upstream's /etc/profile.d/omarchy.sh.
install_omarchy_profile() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local bootstrap=/usr/share/omarchy/default/bash/env-bootstrap
  [ -f "$bootstrap" ] || { warn "no env-bootstrap at $bootstrap; skipping profile wiring"; return 0; }

  log "== Installing /etc/profile.d/omarchy.sh =="
  local live_dest=/etc/profile.d/omarchy.sh
  if (( EUID == 0 )); then
    cat > "$live_dest" <<EOF
# Omarchy Quattro (Fedora) - shell environment. Sources the upstream
# env-bootstrap which defines OMARCHY_PATH and PATH adjustments.
if [ -f "$bootstrap" ]; then
  . "$bootstrap"
fi
EOF
  else
    sudo tee "$live_dest" >/dev/null <<EOF
# Omarchy Quattro (Fedora) - shell environment. Sources the upstream
# env-bootstrap which defines OMARCHY_PATH and PATH adjustments.
if [ -f "$bootstrap" ]; then
  . "$bootstrap"
fi
EOF
  fi
}

# ---------------------------------------------------------------------------
# Phase F - User configuration
# ---------------------------------------------------------------------------

configure_user() {
  local user="${TARGET_USER:-}"
  if [ -z "$user" ]; then
    # pick the first non-root uid>=1000 user (or the sudo user)
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
      user="$SUDO_USER"
    else
      user="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)"
    fi
  fi
  [ -n "$user" ] || { warn "no user to configure; skipping user files"; return 0; }
  id "$user" >/dev/null 2>&1 || { warn "user $user does not exist"; return 0; }
  local home
  home="$(getent passwd "$user" | cut -d: -f6)"

  log "== Configuring user files for $user =="
  local hd="$OMARCHY_ROOT/fedora/files/home"
  local as_user
  if (( EUID == 0 )); then as_user="runuser -u $user --"; else as_user="sudo -u $user"; fi
  if [ -d "$hd" ]; then
    $as_user cp -a "$hd"/. "$home/" 2>/dev/null || true
  fi

  # Enable graphical session for the user.
  local session_file=/usr/share/wayland-sessions/omarchy.desktop
  $as_user mkdir -p "$home/.config" 2>/dev/null || true
  warn "User-level Omarchy config (shell, themes) will be provisioned on first login."
}

# ---------------------------------------------------------------------------
# Phase G - Validation
# ---------------------------------------------------------------------------

validate_install() {
  log "== Validating installation =="
  local -a required=(hyprland quickshell foot fzf git ripgrep gum git-delta)
  local missing=()
  for p in "${required[@]}"; do
    omarchy_pkg_is_installed "$p" || missing+=("$p")
  done
  if (( ${#missing[@]} > 0 )); then
    warn "validation: missing packages: ${missing[*]}"
  else
    log "validation: required packages present"
  fi

  # Validate the Omarchy CLI wiring: the omarchy-* commands should be on PATH
  # and OMARCHY_PATH should resolve to a real tree.
  if [ "$COPY_OMARCHY" = 1 ]; then
    if [ -x /usr/bin/omarchy ] || [ -L /usr/bin/omarchy ]; then
      log "validation: omarchy CLI is on PATH"
    else
      warn "validation: /usr/bin/omarchy not found (CLI wiring may be incomplete)"
    fi
    if [ -e /usr/share/omarchy/version ]; then
      local v
      v="$(cat /usr/share/omarchy/version 2>/dev/null || echo '?')"
      log "validation: Omarchy tree present (version $v)"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  log "Omarchy Quattro for Fedora installer"
  log "Upstream tree: $UPSTREAM"

  verify_prereqs
  [ "$DRY_RUN" = 1 ] && { log "dry-run complete (no changes made)"; exit 0; }

  install_repos
  install_packages
  install_systemd_units
  install_sysctl
  install_udev
  install_dracut
  enable_services
  install_omarchy_tree
  install_omarchy_bin
  install_omarchy_profile
  configure_user
  validate_install

  log "== Installation complete =="
  echo
  printf '\033[1;32m Omarchy Quattro has been installed on Fedora.\033[0m\n'
  echo " Please REBOOT now to start:"
  echo "   sudo systemctl reboot"
  echo
  echo " After reboot, select the Omarchy session at the display manager."
}

main "$@"
