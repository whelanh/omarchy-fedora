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

for arg in "$@"; do
  case "$arg" in
    --no-omarchy)    COPY_OMARCHY=0 ;;
    --dry-run)       DRY_RUN=1 ;;
    --no-firstparty) INSTALL_FIRSTPARTY=0 ;;
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
  # First-party Omarchy binaries (aether, cliamp, herdr, share-picker,
  # omacalc, omacut, omawrite, tensaku, try, ttfx) live in the whelanh/omarchy
  # COPR (see fedora/rpm/copr/README.md).
  if [ "$INSTALL_FIRSTPARTY" = 1 ]; then
    omarchy_fedora_enable_optional_coprs whelanh/omarchy \
      || die "failed to enable whelanh/omarchy COPR"
  fi
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
  log "NOTE: the 10 first-party command binaries (aether, cliamp, herdr,"
       "hyprland-preview-share-picker, omacalc, omacut, omawrite, tensaku, try,"
       "ttfx) are packaged under fedora/rpm and ship from the whelanh/omarchy"
       "COPR (see fedora/rpm/copr/README.md)."
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
    else
      sudo mkdir -p /usr/share/wayland-sessions
      sudo cp -a "$ws_src" /usr/share/wayland-sessions/omarchy.desktop
    fi
  else
    warn "no session desktop entry at $ws_src; Omarchy won't appear at the greeter"
  fi
  if [ -d "$uwsm_env_src" ]; then
    if (( EUID == 0 )); then
      mkdir -p /usr/share/uwsm/env.d
      cp -a "$uwsm_env_src"/. /usr/share/uwsm/env.d/
    else
      sudo mkdir -p /usr/share/uwsm/env.d
      sudo cp -a "$uwsm_env_src"/. /usr/share/uwsm/env.d/
    fi
  else
    warn "no uwsm env dir at $uwsm_env_src"
  fi
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

# Upstream Omarchy grants the browser-accent helper passwordless sudo via
# /etc/sudoers.d/omarchy-theme-browser; without it every theme switch stalls on
# a password prompt. Ship the rule from the installed tree when present.
install_omarchy_sudoers() {
  [ "$COPY_OMARCHY" = 1 ] || return 0

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
  elif [ -n "${SUDO_USER:-}" ]; then
    sudo install -Dm 0440 -o root -g root "$sudoers_src" "$sudoers_dest"
  else
    warn "not root and no sudo user; install $sudoers_src as $sudoers_dest (0440 root:root) manually"
  fi
}

# Omarchy draws its bar/menu glyphs with whatever `monospace` resolves to, and
# upstream ships a fontconfig alias mapping it to "JetBrainsMono Nerd Font".
# Fedora ships neither the alias nor a Nerd Font, so icon-family widgets render
# blank. Enable the alias and pull in the Nerd Font when missing.
install_omarchy_fonts() {
  [ "$COPY_OMARCHY" = 1 ] || return 0

  local conf_src=/usr/share/omarchy/default/fontconfig/conf.avail/50-omarchy.conf
  if [ -f "$conf_src" ]; then
    log "== Enabling /etc/fonts/conf.d/50-omarchy.conf =="
    if (( EUID == 0 )); then
      ln -sf "$conf_src" /etc/fonts/conf.d/50-omarchy.conf
    elif [ -n "${SUDO_USER:-}" ]; then
      sudo ln -sf "$conf_src" /etc/fonts/conf.d/50-omarchy.conf
    else
      warn "skipping fontconfig alias (no /etc write access)"
      return 0
    fi
  else
    warn "no fontconfig alias shipped at $conf_src"
  fi

  if fc-match -f '%{family[0]}' 'JetBrainsMono Nerd Font' 2>/dev/null | grep -qi 'jetbrains'; then
    log "== JetBrainsMono Nerd Font already present =="
    fc-cache -f >/dev/null 2>&1 || true
    return 0
  fi

  # Fedora has no Nerd Font package; fetch the TTF set upstream uses.
  command -v curl >/dev/null 2>&1 || { warn "curl not found; skipping Nerd Font install"; return 0; }
  command -v unzip >/dev/null 2>&1 || { warn "unzip not found; skipping Nerd Font install"; return 0; }

  local tmp dest
  tmp="$(mktemp -d)"
  dest=/usr/share/fonts/jetbrainsmono-nerd
  if ! curl -fsSLo "$tmp/JetBrainsMono.zip" \
      https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip; then
    warn "failed to download JetBrainsMono Nerd Font"
    rm -rf "$tmp"
    return 0
  fi

  if (( EUID == 0 )); then
    mkdir -p "$dest"
    unzip -q -o "$tmp/JetBrainsMono.zip" -d "$tmp/out" 2>/dev/null || true
    install -m 0644 "$tmp"/out/*.ttf "$dest/"
  elif [ -n "${SUDO_USER:-}" ]; then
    sudo mkdir -p "$dest"
    unzip -q -o "$tmp/JetBrainsMono.zip" -d "$tmp/out" 2>/dev/null || true
    sudo install -m 0644 "$tmp"/out/*.ttf "$dest/"
  else
    rm -rf "$tmp"
    warn "skipping Nerd Font install (no /etc write access)"
    return 0
  fi
  rm -rf "$tmp"

  fc-cache -f >/dev/null 2>&1 || true
  if fc-match -f '%{family[0]}' 'JetBrainsMono Nerd Font' 2>/dev/null | grep -qi 'jetbrains'; then
    log "== JetBrainsMono Nerd Font installed =="
  else
    warn "fontconfig still not resolving JetBrainsMono Nerd Font"
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

  # Seed the Omarchy user configs (~/.config) from the vendored upstream
  # config/ tree: hypr/hyprland.lua is what Hyprland 0.55+ loads by default
  # and it bootstraps the whole Omarchy desktop (binds, autostart, shell).
  # Without this seed the session entry would boot stock Hyprland instead.
  local cfg_src="$UPSTREAM/config"
  if [ -d "$cfg_src" ]; then
    $as_user mkdir -p "$home/.config"
    $as_user cp -a "$cfg_src"/. "$home/.config/" 2>/dev/null || true
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

  install_repos
  install_packages
  install_systemd_units
  install_sysctl
  install_udev
  install_dracut
  enable_services
  install_omarchy_tree
  install_omarchy_session
  install_omarchy_bin
  install_omarchy_profile
  install_uwsm_app_shim
  install_omarchy_sudoers
  install_omarchy_fonts
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
