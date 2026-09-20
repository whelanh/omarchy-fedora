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
INSTALL_FIRSTPARTY=1
UPDATE_MODE=0

for arg in "$@"; do
  case "$arg" in
    --no-omarchy)    COPY_OMARCHY=0 ;;
    --dry-run)       DRY_RUN=1 ;;
    --no-firstparty) INSTALL_FIRSTPARTY=0 ;;
    --update)        UPDATE_MODE=1 ;;
    --user)          TARGET_USER="__NEXT__" ;;
    --nvidia)        NVIDIA=1 ;;
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
  # First-party Omarchy packages (aether, cliamp, elsewhen, herdr, share-picker,
  # omacalc, omacut, omawrite, tensaku, try, ttfx) live in the whelanh/omarchy
  # COPR (see fedora/rpm/copr/README.md).
  if [ "$INSTALL_FIRSTPARTY" = 1 ]; then
    omarchy_fedora_enable_optional_coprs whelanh/omarchy \
      || die "failed to enable whelanh/omarchy COPR"
  fi
  # mise (runtime version manager, used by omarchy-default-agent and
  # omarchy-install-dev-env) is NOT in Fedora official; enable its upstream
  # RPM repo. Required so `mise` in base.txt resolves.
  omarchy_fedora_enable_external_repo "https://mise.jdx.dev/rpm/mise.repo" \
    || die "failed to enable the mise RPM repository"
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
  if [ "$INSTALL_FIRSTPARTY" = 1 ]; then
    omarchy_fedora_install_firstparty || die "first-party package installation failed"
  fi
  log "packages installed"
}

# Update-mode backfill: install any manifest packages missing on disk (e.g.
# added to the manifests by an upstream sync since the initial install).
# Best-effort so a missing/unavailable package or a transient repo issue cannot
# abort an update. Repositories are not re-enabled here (they persist from the
# initial install, and re-enabling them would re-run `dnf copr enable`, which
# could fail on a transient network problem and kill the update).
backfill_packages() {
  log "== Backfilling newly-added packages =="
  omarchy_fedora_install_base || warn "base package backfill failed"
  omarchy_fedora_install_desktop || warn "desktop package backfill failed"
  omarchy_fedora_install_applications || warn "application package backfill failed"
  if [ "$INSTALL_FIRSTPARTY" = 1 ]; then
    omarchy_fedora_install_firstparty || warn "first-party package backfill failed"
  fi
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

# Run snapper as the right user. --no-dbus avoids depending on snapperd, which
# is not running during an unattended install/update.
_snapper() {
  if (( EUID == 0 )); then snapper --no-dbus "$@"; else sudo snapper --no-dbus "$@"; fi
}

# snapper produces the btrfs snapshots that grub-btrfs surfaces in the boot
# menu. Install it, create a root timeline config, cap retained snapshots, and
# keep the timeline + cleanup timers running so the cap is actually enforced.
# Idempotent; gated on btrfs since snapper does not apply to other filesystems.
install_snapper() {
  local rootfs
  rootfs="$(findmnt -no FSTYPE / 2>/dev/null || true)"
  if [ "$rootfs" != "btrfs" ]; then
    log "snapper: skipped (root filesystem is $rootfs, not btrfs)"
    return 0
  fi

  log "== snapper: btrfs snapshot timeline =="

  if omarchy_pkg_is_installed snapper; then
    log "  snapper already installed"
  else
    log "  installing snapper"
    if ! omarchy_pkg_install snapper; then
      warn "  snapper install failed"
      return 0
    fi
  fi

  if [ -e /etc/snapper/configs/root ]; then
    log "  snapper root config already exists"
  else
    log "  creating snapper root config"
    if ! _snapper -c root create-config /; then
      warn "  could not create snapper root config"
      return 0
    fi
  fi

  # Cap retained snapshots (tunable). snapper-cleanup.timer enforces this.
  _snapper -c root set-config NUMBER_LIMIT=5 TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=0 TIMELINE_LIMIT_WEEKLY=0 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
    || warn "  could not set snapper snapshot limits"

  _systemctl_enable --now snapper-timeline.timer \
    || warn "  could not enable snapper-timeline.timer"
  _systemctl_enable --now snapper-cleanup.timer \
    || warn "  could not enable snapper-cleanup.timer"
}

# Omarchy on Arch ships Limine + snapshots so a broken upgrade can be rolled
# back from the boot menu. Fedora has no Limine, so offer the GRUB equivalent:
# grub-btrfs (jmarcoshp/grub-btrfs COPR) regenerates GRUB entries for btrfs
# snapshots, and grub-btrfsd.service keeps those entries current. Only applies
# on btrfs-on-GRUB systems; fully idempotent so re-running install.sh --update
# is safe and a pre-existing install (COPR/package/service) is detected.
install_grub_btrfs() {
  local rootfs
  rootfs="$(findmnt -no FSTYPE / 2>/dev/null || true)"
  if [ "$rootfs" != "btrfs" ]; then
    log "grub-btrfs: skipped (root filesystem is $rootfs, not btrfs)"
    return 0
  fi
  if [ ! -e /boot/grub2/grub.cfg ] && [ ! -e /boot/grub/grub.cfg ]; then
    log "grub-btrfs: skipped (no GRUB configuration found)"
    return 0
  fi

  log "== grub-btrfs: boot snapshot rollback =="

  if omarchy_pkg_repo_enabled "copr:copr.fedorainfracloud.org:jmarcoshp:grub-btrfs"; then
    log "  grub-btrfs COPR already enabled"
  else
    log "  enabling jmarcoshp/grub-btrfs COPR"
    if ! omarchy_fedora_enable_optional_coprs jmarcoshp/grub-btrfs; then
      warn "  could not enable jmarcoshp/grub-btrfs COPR; skipping grub-btrfs"
      return 0
    fi
  fi

  if omarchy_pkg_is_installed grub-btrfs; then
    log "  grub-btrfs already installed"
  else
    log "  installing grub-btrfs"
    if ! omarchy_pkg_install grub-btrfs; then
      warn "  grub-btrfs install failed"
      return 0
    fi
  fi

  if systemctl is-enabled --quiet grub-btrfsd.service 2>/dev/null; then
    log "  grub-btrfsd.service already enabled"
  else
    log "  enabling grub-btrfsd.service"
    _systemctl_enable --now grub-btrfsd.service || warn "  could not enable grub-btrfsd.service"
  fi
}

# ---------------------------------------------------------------------------
# Phase E - Omarchy desktop (vendored upstream -> /usr/share/omarchy)
# ---------------------------------------------------------------------------

install_omarchy_tree() {
  [ "$COPY_OMARCHY" = 1 ] || { log "skipping Omarchy desktop copy (--no-omarchy)"; return 0; }
  [ -d "$UPSTREAM" ] || die "vendored upstream not found ($UPSTREAM)"

  log "== Installing Omarchy desktop tree =="
  local dest=/usr/share/omarchy
  # cp -a preserves the source's ownership, which is the invoking user's (this
  # checkout), not root. Left alone, that leaves a package tree in /usr/share
  # writable by a non-root account -- code later executed with sudo elsewhere
  # (omarchy-apply-lock, omarchy-plymouth-set, ...) -- so reset it to root
  # after every copy, matching what a real package install would produce.
  if (( EUID == 0 )); then
    mkdir -p "$dest"
    cp -a "$UPSTREAM"/* "$dest/"
    chown -R root:root "$dest"
  else
    sudo mkdir -p "$dest"
    sudo cp -a "$UPSTREAM"/* "$dest/"
    sudo chown -R root:root "$dest"
  fi
  log "Omarchy tree installed to $dest"
  log "NOTE: the 10 first-party command binaries (aether, cliamp, herdr," \
       "hyprland-preview-share-picker, omacalc, omacut, omawrite, tensaku, try," \
       "ttfx) are packaged under fedora/rpm and ship from the whelanh/omarchy" \
       "COPR (see fedora/rpm/copr/README.md)."
}

# Install the upstream user systemd units (bt-agent, sleep-lock, crash-watch,
# fcitx5, migrate-notify, recover-internal-monitor, speaker-tuning,
# tailscale-receive, and the app.slice.d oomd drop-in) into /usr/lib/systemd/user/,
# mirroring upstream's omarchy-settings PKGBUILD. On a fresh install these units
# are absent, so omarchy-provision-first-run's "enable user systemd units" step
# fails on every login, never writes the first-run done marker, and re-shows the
# "Learn Keybindings" / "Update System" toasts on every boot.
install_omarchy_user_units() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local src="$UPSTREAM/default/systemd/user"
  [ -d "$src" ] || { warn "no user units dir at $src; skipping"; return 0; }

  log "== Installing Omarchy user systemd units =="
  if (( EUID == 0 )); then
    mkdir -p /usr/lib/systemd/user
    cp -a "$src"/. /usr/lib/systemd/user/
    chown -R root:root /usr/lib/systemd/user
  else
    sudo mkdir -p /usr/lib/systemd/user
    sudo cp -a "$src"/. /usr/lib/systemd/user/
    sudo chown -R root:root /usr/lib/systemd/user
  fi
}

# Install the login-manager session entry so the greeter (SDDM on the Fedora
# Sway/companion spins) offers "Omarchy (Hyprland uwsm)" alongside the stock
# Hyprland sessions. Also install the uwsm env that sources the env-bootstrap
# into the session, since uwsm does not read /etc/profile.d.
install_omarchy_session() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local ws_src="$UPSTREAM/default/wayland-sessions/omarchy.desktop"
  local uwsm_env_src="$UPSTREAM/default/uwsm/env.d"
  if [ -f "$ws_src" ]; then
    log "== Installing Omarchy login session =="
    if (( EUID == 0 )); then
      mkdir -p /usr/share/wayland-sessions
      cp -a "$ws_src" /usr/share/wayland-sessions/omarchy.desktop
      chown root:root /usr/share/wayland-sessions/omarchy.desktop
    else
      sudo mkdir -p /usr/share/wayland-sessions
      sudo cp -a "$ws_src" /usr/share/wayland-sessions/omarchy.desktop
      sudo chown root:root /usr/share/wayland-sessions/omarchy.desktop
    fi
  else
    warn "no session desktop entry at $ws_src; Omarchy won't appear at the greeter"
  fi
  if [ -d "$uwsm_env_src" ]; then
    if (( EUID == 0 )); then
      mkdir -p /usr/share/uwsm/env.d
      cp -a "$uwsm_env_src"/. /usr/share/uwsm/env.d/
      chown -R root:root /usr/share/uwsm/env.d
    else
      sudo mkdir -p /usr/share/uwsm/env.d
      sudo cp -a "$uwsm_env_src"/. /usr/share/uwsm/env.d/
      sudo chown -R root:root /usr/share/uwsm/env.d
    fi
  else
    warn "no uwsm env dir at $uwsm_env_src"
  fi
}

# Wire up SDDM's Omarchy greeter, which upstream's pacman package installs
# straight to /etc and /usr/share/sddm; nothing in this installer vendored
# either piece, so SDDM fell back to a generic Breeze theme and its Hyprland
# greeter compositor crash-looped ("Config file '/usr/share/sddm/hyprland.lua'
# is invalid: ... No such file or directory") until both were copied by hand:
#   - etc/sddm.conf.d/{10-theme,10-wayland}.conf select the Omarchy theme and
#     point SDDM's Wayland greeter at start-hyprland.
#   - default/sddm/hyprland.lua is the minimal compositor config
#     10-wayland.conf's CompositorCommand references.
# omarchy-refresh-sddm (run post-install, or after a theme change) still needs
# to publish the actual theme assets into /usr/share/sddm/themes/omarchy —
# this only lays the config and compositor file it depends on.
install_omarchy_sddm_config() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local conf_src="$UPSTREAM/etc/sddm.conf.d"
  local lua_src="$UPSTREAM/default/sddm/hyprland.lua"

  if [ -d "$conf_src" ]; then
    log "== Installing SDDM theme/Wayland config =="
    if (( EUID == 0 )); then
      mkdir -p /etc/sddm.conf.d
      cp -a "$conf_src"/. /etc/sddm.conf.d/
      chown -R root:root /etc/sddm.conf.d
    else
      sudo mkdir -p /etc/sddm.conf.d
      sudo cp -a "$conf_src"/. /etc/sddm.conf.d/
      sudo chown -R root:root /etc/sddm.conf.d
    fi
  else
    warn "no SDDM config at $conf_src; greeter keeps its distro default theme"
  fi

  if [ -f "$lua_src" ]; then
    if (( EUID == 0 )); then
      mkdir -p /usr/share/sddm
      cp -a "$lua_src" /usr/share/sddm/hyprland.lua
      chown root:root /usr/share/sddm/hyprland.lua
    else
      sudo mkdir -p /usr/share/sddm
      sudo cp -a "$lua_src" /usr/share/sddm/hyprland.lua
      sudo chown root:root /usr/share/sddm/hyprland.lua
    fi
  else
    warn "no SDDM Hyprland config at $lua_src; the Wayland greeter compositor will fail to start"
  fi
}

# Publish the Omarchy SDDM theme assets (Main.qml, logo, lock/entry PNGs) into
# /usr/share/sddm/themes/omarchy/. Upstream does this via omarchy-refresh-sddm
# (omarchy-plymouth-set --refresh-sddm-default), which must run as a non-root
# user with sudo and only publishes from a root-owned source tree. Seed the
# default theme here (root-side, verbatim — the same files refresh-sddm ships)
# so the greeter is themed on first boot; `omarchy theme` changes still re-tint
# it through the normal runtime path afterwards.
install_omarchy_sddm_theme() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local theme_src="$UPSTREAM/default/sddm/omarchy"
  [ -d "$theme_src" ] || { warn "no SDDM theme assets at $theme_src; greeter keeps its default theme"; return 0; }

  log "== Installing SDDM Omarchy theme assets =="
  if (( EUID == 0 )); then
    mkdir -p /usr/share/sddm/themes/omarchy
    cp -a "$theme_src"/. /usr/share/sddm/themes/omarchy/
    chown -R root:root /usr/share/sddm/themes/omarchy
  else
    sudo mkdir -p /usr/share/sddm/themes/omarchy
    sudo cp -a "$theme_src"/. /usr/share/sddm/themes/omarchy/
    sudo chown -R root:root /usr/share/sddm/themes/omarchy
  fi
}

# Import omarchy-* commands onto PATH, mirroring the upstream architecture's
# package map: bin/omarchy + bin/omarchy-* -> /usr/bin/omarchy* (with symlinks
# kept under /usr/share/omarchy/bin). This is what makes `omarchy`, `omarchy
# plugin`, `omarchy theme`, etc. callable on Fedora. The main `omarchy`
# dispatcher has no hyphen, so it must be linked explicitly alongside the
# `omarchy-*` subcommands (upstream's env-bootstrap expects /usr/bin/omarchy on
# production installs and does not add /usr/share/omarchy/bin to PATH).
install_omarchy_bin() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local tree=/usr/share/omarchy/bin
  [ -d "$tree" ] || { warn "no bin dir at $tree; skipping CLI wiring"; return 0; }

  log "== Wiring omarchy + omarchy-* commands onto PATH =="
  local cmd
  for cmd in "$tree/omarchy" "$tree"/omarchy-*; do
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

# Upstream's install/config/all.sh runs omarchy-apply-lock, which writes the
# PAM services the Quickshell lock screen authenticates against
# (/etc/pam.d/omarchy-lock-password, and omarchy-lock-fingerprint when a
# fingerprint is enrolled). The Fedora installer otherwise never creates them,
# so the lock screen's password flow is disabled ("missing-pam") until the user
# runs `sudo omarchy-apply-lock` by hand. Run it here (as root) so a fresh
# install locks correctly out of the box. Must come after install_omarchy_bin
# so the omarchy-apply-lock symlink is on PATH.
install_omarchy_lock_pam() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  command -v omarchy-apply-lock >/dev/null 2>&1 \
    || { warn "omarchy-apply-lock not on PATH; skipping lock-screen PAM"; return 0; }

  log "== Configuring lock screen authentication (PAM) =="
  local lock_user="${TARGET_USER:-}"
  if [ -z "$lock_user" ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
    lock_user="$SUDO_USER"
  fi
  if [ -z "$lock_user" ]; then
    lock_user="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)"
  fi
  if (( EUID == 0 )); then
    OMARCHY_INSTALL_USER="$lock_user" omarchy-apply-lock
  else
    sudo OMARCHY_INSTALL_USER="$lock_user" omarchy-apply-lock
  fi
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

# Fedora's uwsm (nett00n/hyprland COPR) ships only the `uwsm app` subcommand,
# not the legacy `uwsm-app` entry point that Omarchy's scripts (o.launch,
# omarchy-launch-terminal, AppLibrary, webapps/tuis) all call. Install a
# system-wide compat shim so `uwsm-app -- <cmd>` works as upstream expects.
install_uwsm_app_shim() {
  local dest=/usr/bin/uwsm-app
  if [ -e "$dest" ]; then
    log "== uwsm-app already present at $dest; skipping shim =="
    return 0
  fi
  command -v /usr/bin/uwsm >/dev/null 2>&1 || { warn "uwsm not found; skipping uwsm-app shim"; return 0; }

  log "== Installing $dest (uwsm-app -> uwsm app) =="
  if (( EUID == 0 )); then
    cat > "$dest" <<'EOF'
#!/bin/sh
# Compat shim: Omarchy calls `uwsm-app -- <cmd>`; Fedora's uwsm ships the
# equivalent as the `uwsm app` subcommand.
exec /usr/bin/uwsm app "$@"
EOF
    chmod +x "$dest"
  else
    sudo tee "$dest" >/dev/null <<'EOF'
#!/bin/sh
# Compat shim: Omarchy calls `uwsm-app -- <cmd>`; Fedora's uwsm ships the
# equivalent as the `uwsm app` subcommand.
exec /usr/bin/uwsm app "$@"
EOF
    sudo chmod +x "$dest"
  fi
}

# Fedora renames Chromium vs what upstream Omarchy hardcodes:
#   - binary        Arch `chromium`       vs Fedora `chromium-browser`
#   - desktop entry Arch `chromium.desktop` vs Fedora `chromium-browser.desktop`
# Omarchy's `omarchy-launch-webapp` (SUPER+SHIFT+A webapps) falls back to
# `chromium.desktop`, and `omarchy-default-browser` uses `chromium.desktop` +
# `command="chromium"`. Rather than patch Omarchy code, present what it expects
# via a compat shim (same philosophy as the uwsm-app shim):
#   - a NoDisplay chromium.desktop stub (hidden from app menus, but resolvable
#     by omarchy-launch-webapp / omarchy-default-browser and usable as the
#     xdg default handler)
#   - a chromium -> chromium-browser binary link
# Never overwrite a real file; idempotent.
install_omarchy_chromium_compat() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  log "== Aligning chromium naming with upstream Omarchy (compat shim) =="

  local -a made=()
  # desktop entry stub: hidden from menus (NoDisplay) but a valid browser handler
  if [ -f /usr/share/applications/chromium-browser.desktop ] \
     && [ ! -e /usr/share/applications/chromium.desktop ]; then
    if (( EUID == 0 )); then
      cat > /usr/share/applications/chromium.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium
GenericName=Web Browser
Comment=Omarchy compatibility alias for Fedora's chromium-browser
Exec=/usr/bin/chromium-browser %U
Terminal=false
NoDisplay=true
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
Categories=Network;WebBrowser;
EOF
    else
      sudo tee /usr/share/applications/chromium.desktop >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium
GenericName=Web Browser
Comment=Omarchy compatibility alias for Fedora's chromium-browser
Exec=/usr/bin/chromium-browser %U
Terminal=false
NoDisplay=true
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
Categories=Network;WebBrowser;
EOF
    fi
    made+=(chromium.desktop)
  fi
  # binary: /usr/bin/chromium -> chromium-browser
  if command -v chromium-browser >/dev/null 2>&1 && [ ! -e /usr/bin/chromium ]; then
    if (( EUID == 0 )); then ln -s chromium-browser /usr/bin/chromium
    else sudo ln -s chromium-browser /usr/bin/chromium; fi
    made+=(/usr/bin/chromium)
  fi

  if [ "${#made[@]}" -gt 0 ]; then
    log "  added chromium compat shim: ${made[*]}"
  else
    log "  no chromium compat shim needed (already present)"
  fi
}


# The upstream omarchy-update is pacman/AUR-specific (pacman -Syu, paccache,
# yay, pacman-key). On Fedora it would fail immediately. Replace the installed
# omarchy-update (the file the `omarchy` dispatcher execs, at
# /usr/share/omarchy/bin/omarchy-update) with a Fedora-native wrapper that
# delegates to this checkout's fedora/scripts/update.sh (dnf upgrade + userspace
# re-sync + migrations). Preserve the # omarchy:* metadata so the dispatcher
# still recognises the command (including requires-sudo). The checkout path is
# embedded at install time; re-run install.sh if you move the checkout.
install_omarchy_update_shim() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local update_sh="$OMARCHY_ROOT/fedora/scripts/update.sh"
  [ -f "$update_sh" ] || { warn "no $update_sh; skipping omarchy-update shim"; return 0; }
  local dest=/usr/share/omarchy/bin/omarchy-update
  if [ -f "$dest" ] && grep -q "Fedora-native omarchy update" "$dest" 2>/dev/null; then
    log "== omarchy-update already wired to the Fedora updater =="
    return 0
  fi
  log "== Wiring omarchy-update to the Fedora updater =="
  if (( EUID == 0 )); then
    cat > "$dest" <<EOF
#!/bin/bash

# omarchy:summary=Update Omarchy and system packages (Fedora)
# omarchy:args=[-y]
# omarchy:examples=omarchy update | omarchy update -y
# omarchy:requires-sudo=true

# Fedora-native omarchy update (delegates to fedora/scripts/update.sh).
# Installed by install.sh; see UPDATING.md.
exec bash "$update_sh" "\$@"
EOF
    chmod +x "$dest"
  else
    sudo tee "$dest" >/dev/null <<EOF
#!/bin/bash

# omarchy:summary=Update Omarchy and system packages (Fedora)
# omarchy:args=[-y]
# omarchy:examples=omarchy update | omarchy update -y
# omarchy:requires-sudo=true

# Fedora-native omarchy update (delegates to fedora/scripts/update.sh).
# Installed by install.sh; see UPDATING.md.
exec bash "$update_sh" "\$@"
EOF
    sudo chmod +x "$dest"
  fi
}

# Upstream's bin/omarchy-pkg-* family (add, drop, missing, present, install,
# remove, aur-*) is a pacman/yay wrapper and fails on Fedora with "pacman:
# command not found". These commands are called by nearly every `omarchy
# install service|app|game|browser ...` flow (including the Tailscale service
# installer) and by the menu guards (`omarchy-pkg-present tailscale`). Replace
# the vendored copies with thin dnf/rpm wrappers that source
# fedora/scripts/lib/pkg.sh (same philosophy as the omarchy-update shim). The
# wrappers preserve the # omarchy:* metadata so the `omarchy` dispatcher still
# recognises the commands. The checkout path is embedded at install time;
# re-run install.sh if you move the checkout.
install_omarchy_pkg_shims() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  local tree=/usr/share/omarchy/bin
  [ -d "$tree" ] || { warn "no bin dir at $tree; skipping pkg shims"; return 0; }
  local pkg_lib="$OMARCHY_ROOT/fedora/scripts/lib/pkg.sh"
  [ -f "$pkg_lib" ] || { warn "no $pkg_lib; skipping pkg shims"; return 0; }

  log "== Installing omarchy-pkg-* shims (dnf/rpm backend) =="

  local _ps_binary _ps_summary _ps_args _ps_examples _ps_reqsudo _ps_fn
  _pkg_shim_write() {
    local dest="$tree/$_ps_binary"
    if (( EUID == 0 )); then
      {
        printf '#!/bin/bash\n\n'
        printf '# omarchy:summary=%s\n' "$_ps_summary"
        [ -n "$_ps_args" ] && printf '# omarchy:args=%s\n' "$_ps_args"
        [ -n "$_ps_examples" ] && printf '# omarchy:examples=%s\n' "$_ps_examples"
        [ "$_ps_reqsudo" = "true" ] && printf '# omarchy:requires-sudo=true\n'
        printf '\n'
        printf '# Fedora-native %s shim (dnf/rpm). Installed by install.sh.\n' "$_ps_binary"
        printf '# shellcheck disable=SC1091\n'
        printf '. "%s" || exit 1\n' "$pkg_lib"
        printf '%s "$@"\n' "$_ps_fn"
      } > "$dest"
      chmod +x "$dest"
    else
      {
        printf '#!/bin/bash\n\n'
        printf '# omarchy:summary=%s\n' "$_ps_summary"
        [ -n "$_ps_args" ] && printf '# omarchy:args=%s\n' "$_ps_args"
        [ -n "$_ps_examples" ] && printf '# omarchy:examples=%s\n' "$_ps_examples"
        [ "$_ps_reqsudo" = "true" ] && printf '# omarchy:requires-sudo=true\n'
        printf '\n'
        printf '# Fedora-native %s shim (dnf/rpm). Installed by install.sh.\n' "$_ps_binary"
        printf '# shellcheck disable=SC1091\n'
        printf '. "%s" || exit 1\n' "$pkg_lib"
        printf '%s "$@"\n' "$_ps_fn"
      } | sudo tee "$dest" >/dev/null
      sudo chmod +x "$dest"
    fi
  }

  _pkg_shim() {
    _ps_binary="$1"; _ps_summary="$2"; _ps_args="$3"; _ps_examples="$4"; _ps_reqsudo="$5"; _ps_fn="$6"
    _pkg_shim_write
  }

  _pkg_shim omarchy-pkg-add \
    "Install Fedora packages if they are missing" \
    "<packages...>" \
    "omarchy pkg add jq ripgrep" \
    "true" omarchy_pkg_add

  _pkg_shim omarchy-pkg-drop \
    "Remove all the named packages from the system if they're installed (otherwise ignore)." \
    "<packages...>" \
    "" \
    "true" omarchy_pkg_drop

  _pkg_shim omarchy-pkg-missing \
    "Returns true if any of the named packages are missing from the system (or false if they're all there)." \
    "<packages...>" \
    "" \
    "false" omarchy_pkg_missing

  _pkg_shim omarchy-pkg-present \
    "Returns true if all of the named packages are installed on the system (or false if any of them are missing)." \
    "<packages...>" \
    "" \
    "false" omarchy_pkg_present

  _pkg_shim omarchy-pkg-install \
    "Show a fuzzy-finder TUI for picking new Fedora packages to install." \
    "" \
    "" \
    "true" omarchy_pkg_install_tui

  _pkg_shim omarchy-pkg-remove \
    "Show a fuzzy-finder TUI for picking packages installed on the system to be removed." \
    "" \
    "" \
    "true" omarchy_pkg_remove_tui

  _pkg_shim omarchy-pkg-aur-add \
    "Install the named packages from the AUR if they're missing (Fedora: installs from Fedora repos instead)." \
    "<packages...>" \
    "" \
    "false" omarchy_pkg_aur_add

  _pkg_shim omarchy-pkg-aur-install \
    "Show a fuzzy-finder TUI for picking new AUR packages to install (Fedora: installs from Fedora repos instead)." \
    "" \
    "" \
    "true" omarchy_pkg_aur_install_tui

  _pkg_shim omarchy-pkg-aur-accessible \
    "Returns true if the AUR is up and available." \
    "" \
    "" \
    "false" omarchy_pkg_aur_accessible
}

# Upstream's `version` file is stale (it reads 4.0.0.alpha even on the v4.0.2
# release tag), so derive the real version from the git refs: the latest v* tag
# plus the current quattro HEAD short sha. Written to /usr/share/omarchy/version
# so validate_install / omarchy update report a meaningful version.
install_omarchy_version() {
  [ "$COPY_OMARCHY" = 1 ] || return 0
  [ -d /usr/share/omarchy ] || return 0
  command -v git >/dev/null 2>&1 || return 0

  local sha tag ver
  sha="$(git ls-remote https://github.com/omacom/omarchy.git refs/heads/quattro 2>/dev/null | awk '{print $1}')"
  tag="$(git ls-remote --tags --refs https://github.com/omacom/omarchy.git 'v*' 2>/dev/null \
         | awk '{print $2}' | sed 's#refs/tags/##' | sort -V | tail -1)"
  if [ -n "$sha" ]; then
    ver="${tag:-quattro}-${sha:0:10}"
  elif [ -n "$tag" ]; then
    ver="$tag"
  else
    warn "could not resolve the Omarchy version; leaving the existing version file"
    return 0
  fi

  log "== Omarchy userspace version: $ver =="
  if (( EUID == 0 )); then
    printf '%s\n' "$ver" > /usr/share/omarchy/version
  else
    printf '%s\n' "$ver" | sudo tee /usr/share/omarchy/version >/dev/null
  fi
}

# Upstream Omarchy grants the browser-accent helper passwordless sudo via
# /etc/sudoers.d/omarchy-theme-browser; without it every theme switch stalls on
# a password prompt. Ship the rule from the installed tree when present.
install_omarchy_sudoers() {  [ "$COPY_OMARCHY" = 1 ] || return 0

  local sudoers_src=/usr/share/omarchy/etc/sudoers.d/omarchy-theme-browser
  [ -f "$sudoers_src" ] || { warn "no sudoers rule shipped at $sudoers_src"; return 0; }
  command -v visudo >/dev/null 2>&1 || { warn "visudo not found; skipping sudoers rule"; return 0; }

  visudo -c -f "$sudoers_src" >/dev/null 2>&1 || { warn "skipping invalid sudoers source $sudoers_src"; return 0; }

  local sudoers_dest=/etc/sudoers.d/omarchy-theme-browser
  if [ -f "$sudoers_dest" ] && ! visudo -c -f "$sudoers_dest" >/dev/null 2>&1; then
    warn "skipping bad existing $sudoers_dest; fix it manually"
    return 0
  fi

  log "== Installing $sudoers_dest =="
  if (( EUID == 0 )); then
    install -Dm 0440 -o root -g root "$sudoers_src" "$sudoers_dest"
  else
    sudo install -Dm 0440 -o root -g root "$sudoers_src" "$sudoers_dest"
  fi
}

# Omarchy draws its bar/menu glyphs with whatever `monospace` resolves to
# (aliased to JetBrainsMono Nerd Font) plus a small bundled icon font (family
# "omarchy") for brand marks -- the logo, agent/app glyphs -- that Nerd Fonts
# doesn't carry, referenced by menu entries as "iconFont":"omarchy". Upstream
# ships the fontconfig alias and both fonts via pacman packages
# (omarchy-settings owns the icon font); Fedora has neither, so icon-family
# widgets -- including the bar's top-left Omarchy logo button -- render blank
# without this. Enable the alias and install whichever font is missing.
install_omarchy_fonts() {
  [ "$COPY_OMARCHY" = 1 ] || return 0

  local conf_src=/usr/share/omarchy/default/fontconfig/conf.avail/50-omarchy.conf
  if [ -f "$conf_src" ]; then
    log "== Enabling /etc/fonts/conf.d/50-omarchy.conf =="
    if (( EUID == 0 )); then
      ln -sf "$conf_src" /etc/fonts/conf.d/50-omarchy.conf
    else
      sudo ln -sf "$conf_src" /etc/fonts/conf.d/50-omarchy.conf
    fi
  else
    warn "no fontconfig alias shipped at $conf_src"
  fi

  local need_cache=0

  if fc-list : family 2>/dev/null | tr ',' '\n' | grep -Fx 'JetBrainsMono Nerd Font' >/dev/null; then
    log "== JetBrainsMono Nerd Font already present =="
  elif ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; skipping Nerd Font install"
  elif ! command -v unzip >/dev/null 2>&1; then
    warn "unzip not found; skipping Nerd Font install"
  else
    # Fedora has no Nerd Font package; fetch the TTF set upstream uses.
    local tmp dest
    tmp="$(mktemp -d)"
    dest=/usr/share/fonts/jetbrainsmono-nerd
    if curl -fsSLo "$tmp/JetBrainsMono.zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip; then
      if (( EUID == 0 )); then
        mkdir -p "$dest"
        unzip -q -o "$tmp/JetBrainsMono.zip" -d "$tmp/out" 2>/dev/null || true
        install -m 0644 "$tmp"/out/*.ttf "$dest/"
      else
        sudo mkdir -p "$dest"
        unzip -q -o "$tmp/JetBrainsMono.zip" -d "$tmp/out" 2>/dev/null || true
        sudo install -m 0644 "$tmp"/out/*.ttf "$dest/"
      fi
      need_cache=1
    else
      warn "failed to download JetBrainsMono Nerd Font"
    fi
    rm -rf "$tmp"
  fi

  # The icon font is already vendored in the Omarchy tree (no download needed).
  local icon_src=/usr/share/omarchy/default/fonts/omarchy/omarchy.ttf
  local icon_dest=/usr/share/fonts/omarchy/omarchy.ttf
  if [ ! -f "$icon_src" ]; then
    warn "no Omarchy icon font shipped at $icon_src"
  elif [ -f "$icon_dest" ] && cmp -s "$icon_src" "$icon_dest"; then
    log "== Omarchy icon font already installed =="
  else
    log "== Installing Omarchy icon font =="
    if (( EUID == 0 )); then
      mkdir -p /usr/share/fonts/omarchy
      install -m 0644 "$icon_src" "$icon_dest"
    else
      sudo mkdir -p /usr/share/fonts/omarchy
      sudo install -m 0644 "$icon_src" "$icon_dest"
    fi
    need_cache=1
  fi

  (( need_cache )) && { fc-cache -f >/dev/null 2>&1 || true; }

  fc-list : family 2>/dev/null | tr ',' '\n' | grep -Fx 'JetBrainsMono Nerd Font' >/dev/null \
    || warn "fontconfig still not resolving JetBrainsMono Nerd Font"
  fc-list : family 2>/dev/null | tr ',' '\n' | grep -Fx 'omarchy' >/dev/null \
    || warn "fontconfig still not resolving the Omarchy icon font"
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
    $as_user cp -a -n "$hd"/. "$home/" 2>/dev/null || true
  fi

  # Seed the Omarchy user configs (~/.config) from the vendored upstream
  # config/ tree: hypr/hyprland.lua is what Hyprland 0.55+ loads by default
  # and it bootstraps the whole Omarchy desktop (binds, autostart, shell).
  # Without this seed the session entry would boot stock Hyprland instead.
  #
  # -n (--no-clobber) means we only place files the user does not already have,
  # so `omarchy update` (which re-runs `install.sh --update`) never overwrites
  # user edits such as the bar layout in ~/.config/omarchy/shell.json. This
  # mirrors upstream, where existing users resync individual files explicitly
  # via `omarchy refresh <config>` rather than having ~/.config clobbered.
  # New files shipped upstream still land on the user's system, and future
  # users get a full copy via /etc/skel below.
  local cfg_src="$UPSTREAM/config"
  local input_lua_seeded=0
  [ -e "$home/.config/hypr/input.lua" ] || input_lua_seeded=1
  if [ -d "$cfg_src" ]; then
    $as_user mkdir -p "$home/.config"
    $as_user cp -a -n "$cfg_src"/. "$home/.config/" 2>/dev/null || true
    # Seed /etc/skel so future users get the same desktop.
    if (( EUID == 0 )); then
      mkdir -p /etc/skel/.config
      cp -a "$cfg_src"/. /etc/skel/.config/ 2>/dev/null || true
    else
      sudo mkdir -p /etc/skel/.config
      sudo cp -a "$cfg_src"/. /etc/skel/.config/ 2>/dev/null || true
    fi
  else
    warn "no config tree at $cfg_src; user configs not seeded"
  fi

  # Pre-fill the keyboard layout on a fresh seed. Upstream ships input.lua with
  # kb_layout fully commented out, so Hyprland falls back to its own built-in
  # "us" default -- but Fedora's installer (Anaconda) already asked for and set
  # a real layout system-wide (readable via `localectl status`), which
  # Hyprland never consults on its own. Without this, every fresh install with
  # a non-US keyboard boots into the wrong layout until the user manually
  # edits input.lua. Only touches a layout we just seeded this run, never an
  # existing (possibly already-customized) input.lua.
  if [ "$input_lua_seeded" = 1 ] && [ -f "$home/.config/hypr/input.lua" ] && command -v localectl >/dev/null 2>&1; then
    local x11_layout x11_variant x11_model
    x11_layout="$(localectl status 2>/dev/null | awk -F': ' '/X11 Layout/ {print $2}')"
    x11_variant="$(localectl status 2>/dev/null | awk -F': ' '/X11 Variant/ {print $2}')"
    x11_model="$(localectl status 2>/dev/null | awk -F': ' '/X11 Model/ {print $2}')"
    # localectl prints the literal string "n/a" for a field systemd-localed
    # never had a value for (e.g. a minimal install with only a VC keymap set,
    # no X11 keymap configured at all -- common on the installs this script
    # targets). Treat that the same as unset: writing kb_layout = "n/a" would
    # hand Hyprland an invalid xkb layout, and since this only runs once on
    # the fresh seed it would never self-heal.
    [ "$x11_layout" = "n/a" ] && x11_layout=""
    [ "$x11_variant" = "n/a" ] && x11_variant=""
    [ "$x11_model" = "n/a" ] && x11_model=""
    if [ -n "$x11_layout" ] && [ "$x11_layout" != "us" ]; then
      log "== Setting Hyprland keyboard layout to '$x11_layout' (from localectl) =="
      {
        printf -- '-- Auto-detected from the system keyboard layout (localectl) at install time.\n'
        printf -- '-- Edit or remove freely -- this only ran once, on first setup.\n'
        printf -- 'hl.config({\n  input = {\n    kb_layout = "%s",\n' "$x11_layout"
        [ -n "$x11_variant" ] && printf -- '    kb_variant = "%s",\n' "$x11_variant"
        [ -n "$x11_model" ] && printf -- '    kb_model = "%s",\n' "$x11_model"
        printf -- '  },\n})\n\n'
      } | $as_user tee "$home/.config/hypr/input.lua.new" >/dev/null
      $as_user bash -c 'cat "$1" >> "$2" && mv "$2" "$1"' _ "$home/.config/hypr/input.lua" "$home/.config/hypr/input.lua.new"
    fi
  fi

  # Seed Omarchy branding (screensaver + About ASCII art). Upstream ships
  # these two files via /etc/skel from the omarchy-settings package (see
  # docs/file-layout.md); the Fedora port has no equivalent package, so
  # nothing ever creates ~/.config/omarchy/branding/ here. Left unseeded,
  # the screensaver's `ttfx -i ~/.config/omarchy/branding/screensaver.txt`
  # has no file to read and fails with "error reading input file" the first
  # time it fires. Use "omadora" (this fork's own wordmark) for the
  # screensaver instead of upstream's "Omarchy" text; the About screen keeps
  # the stock icon. Only fills in files the user doesn't already have, same
  # -n semantics as the config seed above, and reseeds /etc/skel for future
  # users.
  local branding_dir="$home/.config/omarchy/branding"
  $as_user mkdir -p "$branding_dir"
  if [ ! -e "$branding_dir/screensaver.txt" ] && command -v omarchy-ascii >/dev/null 2>&1; then
    omarchy-ascii omadora | $as_user tee "$branding_dir/screensaver.txt" >/dev/null
  fi
  if [ ! -e "$branding_dir/about.txt" ] && [ -f /usr/share/omarchy/icon.txt ]; then
    $as_user tee "$branding_dir/about.txt" >/dev/null < /usr/share/omarchy/icon.txt
  fi
  local skel_branding=/etc/skel/.config/omarchy/branding
  if (( EUID == 0 )); then
    mkdir -p "$skel_branding"
    if [ ! -e "$skel_branding/screensaver.txt" ] && command -v omarchy-ascii >/dev/null 2>&1; then
      omarchy-ascii omadora > "$skel_branding/screensaver.txt"
    fi
    [ -e "$skel_branding/about.txt" ] || cp "/usr/share/omarchy/icon.txt" "$skel_branding/about.txt" 2>/dev/null || true
  else
    sudo mkdir -p "$skel_branding"
    if [ ! -e "$skel_branding/screensaver.txt" ] && command -v omarchy-ascii >/dev/null 2>&1; then
      omarchy-ascii omadora | sudo tee "$skel_branding/screensaver.txt" >/dev/null
    fi
    [ -e "$skel_branding/about.txt" ] || sudo cp "/usr/share/omarchy/icon.txt" "$skel_branding/about.txt" 2>/dev/null || true
  fi

  # Mark the upstream (Arch-specific) migrations as done in the user's state, so
  # omarchy-migrate-notify.service (installed with the user units) doesn't nag
  # about "N pending migrations" on every login. The Fedora port does not run
  # upstream's pacman-based omarchy-migrate; it runs its own fedora/migrations/
  # via omarchy_fedora_migrate (state under /var/lib/omarchy-fedora/). This
  # mirrors upstream's omarchy-provision-user --first-install, which marks every
  # shipped migration complete on a fresh install.
  local mig_dir="$home/.local/state/omarchy/migrations"
  if [ -d "$UPSTREAM/migrations" ]; then
    $as_user mkdir -p "$mig_dir"
    local m
    for m in "$UPSTREAM/migrations"/*.sh; do
      [ -f "$m" ] || continue
      $as_user touch "$mig_dir/$(basename "$m")" 2>/dev/null || true
    done
  fi

  # Enable graphical session for the user.
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

  if [ "$UPDATE_MODE" = 1 ]; then
    log "== Update mode: skipping repository setup (repos persist); backfilling packages =="
    backfill_packages
  else
    install_repos
    install_packages
  fi
  install_systemd_units
  install_sysctl
  install_udev
  install_dracut
  enable_services
  install_snapper
  install_grub_btrfs
  install_omarchy_tree
  install_omarchy_user_units
  install_omarchy_session
  install_omarchy_sddm_config
  install_omarchy_sddm_theme
  install_omarchy_bin
  install_omarchy_lock_pam
  install_omarchy_update_shim
  install_omarchy_pkg_shims
  install_omarchy_profile
  install_uwsm_app_shim
  install_omarchy_chromium_compat
  install_omarchy_sudoers
  install_omarchy_fonts
  install_omarchy_version
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
