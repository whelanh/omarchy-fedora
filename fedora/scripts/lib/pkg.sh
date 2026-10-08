#!/bin/bash
# omarchy-fedora package abstraction (dnf/rpm backend)
#
# This implements the semantic package-manager API used by the Omarchy Fedora
# compatibility layer. It deliberately does NOT expose `dnf` directly to the
# rest of the scripts; callers use the omarchy_pkg_* functions below.
#
# Required semantics (see spec section 6):
#   omarchy_pkg_install        install packages if absent
#   omarchy_pkg_remove         remove packages if installed
#   omarchy_pkg_update         refresh repository metadata
#   omarchy_pkg_upgrade        upgrade all installed packages
#   omarchy_pkg_is_installed   check whether a package is installed
#   omarchy_pkg_install_file   install a local .rpm file
#   omarchy_pkg_enable_repo    enable a repository (COPR / dnf repo)
#   omarchy_pkg_query          query package info
#
# Design goals:
#   - non-interactive (-y) where appropriate
#   - fail safe: nonzero exit on real failure
#   - preserve useful error output
#   - handle already-installed packages idempotently
#   - handle unavailable packages
#   - distinguish package-not-found from transaction failure
#   - correct root/sudo execution
#   - avoid unnecessary package-manager invocations
#
# This file is sourced by the bootstrap and install scripts. It must be
# shell-safe to source repeatedly (idempotent).

# Guard against multiple sourcing
if [ -n "${OMARCHY_FEDORA_PKG_LIB:-}" ]; then return 0 2>/dev/null || exit 0; fi
OMARCHY_FEDORA_PKG_LIB=1

# --- Menu package-name translation ----------------------------------------
# The Omarchy SUPER+SPACE menu install rows call omarchy-pkg-add/-present with
# Arch/AUR package names. Map those to Fedora strategies (dnf name, COPR, or
# Flathub) via fedora/mappings/menu-packages.conf. Unlisted names pass through
# to dnf unchanged. Parsed in bash so the runtime shim needs no Python/PyYAML.
_PKG_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MENU_PACKAGES_CONF="$_PKG_LIB_DIR/../../mappings/menu-packages.conf"

declare -A _OMARCHY_MENU_SRC=() _OMARCHY_MENU_PKGS=() _OMARCHY_MENU_REPO=() \
  _OMARCHY_MENU_CMD=() _OMARCHY_MENU_DESKTOP=() _OMARCHY_MENU_FALLBACK=()
_OMARCHY_MENU_LOADED=""

_omarchy_menu_load() {
  [ -n "$_OMARCHY_MENU_LOADED" ] && return 0
  _OMARCHY_MENU_LOADED=1
  [ -r "$MENU_PACKAGES_CONF" ] || return 0
  local line name src pkgs repo cmd desktop fallback
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [ -n "${line//[[:space:]]/}" ] || continue
    IFS='|' read -r name src pkgs repo cmd desktop fallback <<<"$line"
    name="${name//[[:space:]]/}"
    [ -n "$name" ] || continue
    _OMARCHY_MENU_SRC["$name"]="$src"
    _OMARCHY_MENU_PKGS["$name"]="$pkgs"
    _OMARCHY_MENU_REPO["$name"]="$repo"
    _OMARCHY_MENU_CMD["$name"]="$cmd"
    _OMARCHY_MENU_DESKTOP["$name"]="$desktop"
    _OMARCHY_MENU_FALLBACK["$name"]="$fallback"
  done < "$MENU_PACKAGES_CONF"
}

# Resolve an Arch/AUR name to "<source>|<packages>|<repo>|<cmd>|<desktop>|<fallback>".
# Unlisted names resolve as "fedora|<name>||||".
_omarchy_pkg_resolve() {
  _omarchy_menu_load
  local name="$1"
  if [ -z "${_OMARCHY_MENU_SRC[$name]+x}" ]; then
    printf 'fedora|%s||||\n' "$name"
  else
    printf '%s|%s|%s|%s|%s|%s\n' \
      "${_OMARCHY_MENU_SRC[$name]}" "${_OMARCHY_MENU_PKGS[$name]}" \
      "${_OMARCHY_MENU_REPO[$name]}" "${_OMARCHY_MENU_CMD[$name]}" \
      "${_OMARCHY_MENU_DESKTOP[$name]}" "${_OMARCHY_MENU_FALLBACK[$name]}"
  fi
}

# --- Locale / environment -------------------------------------------------

# Force C locale so error messages are parseable and stable.
export LC_ALL="${LC_ALL:-C}"

# --- Escape RPM / dnf names -----------------------------------------------

# RPM package names never contain whitespace or quotes; validate+normalize.
omarchy_pkg_normalize() {
  local name="$1"
  case "$name" in
    *' '*) echo "invalid package name (contains space): $name" >&2; return 1 ;;
  esac
  printf '%s' "$name"
}

# --- Root execution -------------------------------------------------------

_omarchy_dnf() {
  if (( EUID == 0 )); then
    dnf "$@"
  else
    sudo dnf "$@"
  fi
}

# --- Flatpak helpers ------------------------------------------------------
# Run flatpak as root (system install) or via sudo when unprivileged.
_omarchy_flatpak() {
  if (( EUID == 0 )); then
    flatpak "$@"
  else
    sudo flatpak "$@"
  fi
}

# Install Flathub app ids system-wide, ensuring the flathub remote exists.
_omarchy_pkg_flatpak_install() {
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "omarchy: flatpak is not installed; cannot install: $*" >&2
    return 1
  fi
  _omarchy_flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
  _omarchy_flatpak install -y --noninteractive flathub "$@"
}

# Write a system file (with sudo when unprivileged). Reads content on stdin.
_omarchy_write_system_file() {
  local path="$1" mode="${2:-0644}"
  if (( EUID == 0 )); then
    cat > "$path" && chmod "$mode" "$path"
  else
    sudo tee "$path" >/dev/null && sudo chmod "$mode" "$path"
  fi
}

# Best-effort Flatpak integration so upstream's later native-integration steps
# have something to act on: expose the command upstream launches via a /usr/bin
# wrapper, alias the desktop id upstream expects, and (for Chromium-family
# browsers) bind-mount the host machine-policy dir into the sandbox so
# `omarchy-theme-set-browser` color.json applies. All are idempotent and
# non-fatal: a failure must not break the install.
_omarchy_pkg_flatpak_integrate() {
  local cmd="$1" desktop="$2" appid="$3"
  case "$appid" in
    com.google.Chrome)  _omarchy_flatpak override --system --filesystem=/etc/opt/chrome:ro "$appid" >/dev/null 2>&1 || true ;;
    com.microsoft.Edge) _omarchy_flatpak override --system --filesystem=/etc/opt/edge:ro "$appid" >/dev/null 2>&1 || true ;;
    com.brave.Browser)  _omarchy_flatpak override --system --filesystem=/etc/brave:ro "$appid" >/dev/null 2>&1 || true ;;
  esac
  if [ -n "$cmd" ]; then
    printf '#!/bin/sh\n# omarchy: Flatpak launcher for %s (installed by the Omarchy Fedora layer).\nexec /usr/bin/flatpak run %s "$@"\n' \
      "$appid" "$appid" \
      | _omarchy_write_system_file "/usr/bin/$cmd" 0755 || true
  fi
  if [ -n "$desktop" ]; then
    _omarchy_write_system_file "/usr/share/applications/$desktop" 0644 <<EOF || true
[Desktop Entry]
Type=Application
Name=${cmd:-$appid}
Exec=/usr/bin/flatpak run $appid %U
Terminal=false
NoDisplay=true
EOF
  fi
}

# Add a vendor repo (repo=.repo URL) or install a direct RPM (repo=URL).
_omarchy_pkg_native_install() {
  local source="$1" pkgs="$2" repo="$3"
  case "$source" in
    rpm)
      _omarchy_dnf install -y "$repo"
      ;;
    repo)
      if dnf --version 2>&1 | grep -q '^dnf5'; then
        _omarchy_dnf config-manager addrepo --from-repofile "$repo" >/dev/null 2>&1 \
          || return 1
      else
        _omarchy_dnf config-manager --add-repo "$repo" >/dev/null 2>&1 || return 1
      fi
      _omarchy_dnf install -y --skip-unavailable $pkgs
      ;;
    copr)
      omarchy_pkg_enable_repo copr "$repo" >/dev/null 2>&1 || return 1
      _omarchy_dnf install -y --skip-unavailable $pkgs
      ;;
    *)
      _omarchy_dnf install -y --skip-unavailable $pkgs
      ;;
  esac
}

# --- is_installed ---------------------------------------------------------
# Success (0) if the named package is installed. The name is translated through
# the menu map: native rpm first, then the Flathub fallback.
omarchy_pkg_is_installed() {
  local name src pkgs repo cmd desktop fb p
  name="$(omarchy_pkg_normalize "$1")" || return 2
  IFS='|' read -r src pkgs repo cmd desktop fb < <(_omarchy_pkg_resolve "$name")
  case "$src" in
    flatpak) flatpak info "$pkgs" >/dev/null 2>&1 ;;
    unavailable) return 1 ;;
    *)
      local all=1
      for p in $pkgs; do
        rpm -q "$p" >/dev/null 2>&1 || { all=0; break; }
      done
      (( all )) && return 0
      [ -n "$fb" ] && flatpak info "$fb" >/dev/null 2>&1 && return 0
      return 1
      ;;
  esac
}

# --- install --------------------------------------------------------------
# Installs the named packages if any are missing. Names are translated through
# the menu map (dnf / COPR / vendor repo / direct RPM / Flatpak), with a Flathub
# fallback for native sources. Idempotent.
omarchy_pkg_install() {
  local name src pkgs repo cmd desktop fb p s app c d
  local -a flat_specs=()
  local rc=0

  for name in "$@"; do
    IFS='|' read -r src pkgs repo cmd desktop fb < <(_omarchy_pkg_resolve "$name")
    case "$src" in
      unavailable)
        echo "omarchy: '$name' has no Fedora/Flathub source; skipping" >&2
        continue
        ;;
      flatpak)
        flatpak info "$pkgs" >/dev/null 2>&1 || flat_specs+=("$pkgs|$cmd|$desktop")
        continue
        ;;
    esac

    # Native source. Skip when already installed.
    local need=0
    for p in $pkgs; do rpm -q "$p" >/dev/null 2>&1 || need=1; done
    (( !need )) && continue

    if _omarchy_pkg_native_install "$src" "$pkgs" "$repo"; then
      local ok=1
      for p in $pkgs; do rpm -q "$p" >/dev/null 2>&1 || ok=0; done
      (( ok )) && continue
    fi

    if [ -n "$fb" ]; then
      echo "omarchy: native install failed for '$name'; falling back to Flatpak $fb" >&2
      flat_specs+=("$fb|$cmd|$desktop")
    else
      echo "omarchy: failed to install '$name'" >&2
      rc=1
    fi
  done

  if (( ${#flat_specs[@]} > 0 )); then
    local -a apps=()
    for s in "${flat_specs[@]}"; do
      IFS='|' read -r app c d <<<"$s"
      apps+=("$app")
    done
    _omarchy_pkg_flatpak_install "${apps[@]}" || rc=1
    for s in "${flat_specs[@]}"; do
      IFS='|' read -r app c d <<<"$s"
      _omarchy_pkg_flatpak_integrate "$c" "$d" "$app" || true
    done
  fi

  return $rc
}

# --- install_file ---------------------------------------------------------
# Install a local .rpm file with dependency resolution.
omarchy_pkg_install_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "omarchy: package file not found: $file" >&2
    return 2
  fi
  _omarchy_dnf install -y "$file"
}

# --- remove ---------------------------------------------------------------
# Remove the named packages only if installed. Names are translated through the
# menu map (dnf / Flatpak, including the fallback). Idempotent.
omarchy_pkg_remove() {
  local name src pkgs repo cmd desktop fb p
  local -a dnf_installed=() flatpaks=()

  for name in "$@"; do
    IFS='|' read -r src pkgs repo cmd desktop fb < <(_omarchy_pkg_resolve "$name")
    case "$src" in
      unavailable) ;;
      flatpak) flatpak info "$pkgs" >/dev/null 2>&1 && flatpaks+=("$pkgs") ;;
      *)
        for p in $pkgs; do
          rpm -q "$p" >/dev/null 2>&1 && dnf_installed+=("$p")
        done
        [ -n "$fb" ] && flatpak info "$fb" >/dev/null 2>&1 && flatpaks+=("$fb")
        ;;
    esac
  done

  if (( ${#dnf_installed[@]} > 0 )); then
    _omarchy_dnf remove -y "${dnf_installed[@]}"
  fi
  if (( ${#flatpaks[@]} > 0 )); then
    _omarchy_flatpak uninstall -y "${flatpaks[@]}"
  fi
  return 0
}

# --- update (refresh metadata) --------------------------------------------
# --refresh forces a fresh metadata download. dnf5's bare `makecache` honours
# metadata_expire and can leave a stale cache in place, which made
# `omarchy update` resolve against old metadata ("Nothing to do") even when the
# COPR had newer packages (e.g. cliamp 2.0.1).
omarchy_pkg_update() {
  _omarchy_dnf --refresh makecache
}

# --- upgrade (full system upgrade) ----------------------------------------
# --refresh as a backstop so the upgrade always resolves against current
# metadata even if the makecache step above was skipped or failed.
omarchy_pkg_upgrade() {
  _omarchy_dnf --refresh upgrade -y
}

# --- enable_repo ----------------------------------------------------------
# Enable a repository. Supports:
#   omarchy_pkg_enable_repo copr OWNER/NAME
#   omarchy_pkg_enable_repo repo /etc/yum.repos.d/foo.repo  (a repo file path)
omarchy_pkg_enable_repo() {
  local kind="$1"; shift
  case "$kind" in
    copr)
      local owner_name="$1"
      if ! command -v dnf-plugins-core >/dev/null 2>&1; then
        _omarchy_dnf install -y 'dnf-command(copr)' >/dev/null \
          || _omarchy_dnf install -y dnf-plugins-core >/dev/null
      fi
      if [ -z "${COPR_DISABLE:-}" ]; then
        _omarchy_dnf copr enable -y "$owner_name"
      else
        echo "omarchy: COPR disabled by env (COPR_DISABLE set); skipping $owner_name" >&2
      fi
      ;;
    repo)
      # a local .repo file to drop into /etc/yum.repos.d/
      local file="$1"
      if [ ! -f "$file" ]; then
        echo "omarchy: repo file not found: $file" >&2
        return 2
      fi
      if (( EUID == 0 )); then
        cp "$file" /etc/yum.repos.d/
      else
        sudo cp "$file" /etc/yum.repos.d/
      fi
      ;;
    *)
      echo "omarchy: unknown repo kind: $kind" >&2
      return 2
      ;;
  esac
}

# --- query ----------------------------------------------------------------
# Query package info. With no args, list all installed packages.
omarchy_pkg_query() {
  if (( $# == 0 )); then
    rpm -qa
    return $?
  fi
  local pkg
  pkg="$(omarchy_pkg_normalize "$1")" || return 2
  dnf info "$pkg"
}

# --- provides -------------------------------------------------------------
# Ask which package provides a file path or command. Helpful for package
# mapping discovery.
omarchy_pkg_provides() {
  _omarchy_dnf provides "$1"
}

# --- repo_available -------------------------------------------------------
# Success if a repository id is already enabled.
omarchy_pkg_repo_enabled() {
  local id="$1"
  dnf repolist --enabled 2>/dev/null | awk '{print $1}' | grep -qx "$id"
}

# ---------------------------------------------------------------------------
# omarchy-pkg-* command shims
# ---------------------------------------------------------------------------
# These mirror the upstream bin/omarchy-pkg-* command contracts (including
# their exit-code semantics) on the dnf/rpm backend. install.sh installs thin
# wrappers at /usr/share/omarchy/bin/omarchy-pkg-* that source this file and
# dispatch to the functions below, replacing the vendored pacman-based
# implementations on Fedora without editing anything under upstream/ (same
# philosophy as the omarchy-update shim).

# omarchy-pkg-missing: 0 (true) if ANY named package is missing, 1 if all present.
omarchy_pkg_missing() {
  local pkg
  for pkg in "$@"; do
    omarchy_pkg_is_installed "$pkg" || return 0
  done
  return 1
}

# omarchy-pkg-present: 0 (true) if ALL named packages are present, 1 otherwise.
omarchy_pkg_present() {
  local pkg
  for pkg in "$@"; do
    omarchy_pkg_is_installed "$pkg" || return 1
  done
  return 0
}

# omarchy-pkg-add: install the named packages if missing, then verify.
# Entries the menu map marks `unavailable` are skipped with a warning rather
# than failing the whole install (some Omarchy install scripts use `set -e`).
omarchy_pkg_add() {
  omarchy_pkg_install "$@" || return 1
  local pkg src pkgs repo cmd desktop fb
  for pkg in "$@"; do
    IFS='|' read -r src pkgs repo cmd desktop fb < <(_omarchy_pkg_resolve "$pkg")
    [ "$src" = unavailable ] && continue
    if ! omarchy_pkg_is_installed "$pkg"; then
      printf '\033[31mError: Package '\''%s'\'' did not install\033[0m\n' "$pkg" >&2
      return 1
    fi
  done
  return 0
}

# omarchy-pkg-drop: remove the named packages only if installed.
omarchy_pkg_drop() {
  omarchy_pkg_remove "$@"
}

# omarchy-pkg-install: fzf TUI over available dnf packages.
omarchy_pkg_install_tui() {
  local fzf_args=(
    --multi
    --preview 'dnf info {1}'
    --preview-label='alt-p: toggle description, alt-j/k: scroll, tab: multi-select'
    --preview-label-pos='bottom'
    --preview-window 'down:65%:wrap'
    --bind 'alt-p:toggle-preview'
    --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up'
    --bind 'alt-k:preview-up,alt-j:preview-down'
    --color 'pointer:green,marker:green'
  )

  local pkg_names
  pkg_names="$(dnf repoquery --qf '%{name}\n' 2>/dev/null | sort -u | fzf "${fzf_args[@]}")"

  if [[ -n $pkg_names ]]; then
    local -a pkgs
    mapfile -t pkgs <<< "$pkg_names"
    _omarchy_dnf install -y "${pkgs[@]}" || return 1
  fi
  return 0
}

# omarchy-pkg-remove: fzf TUI over installed dnf packages.
omarchy_pkg_remove_tui() {
  local fzf_args=(
    --multi
    --preview 'dnf info {1}'
    --preview-label='alt-p: toggle description, alt-j/k: scroll, tab: multi-select'
    --preview-label-pos='bottom'
    --preview-window 'down:65%:wrap'
    --bind 'alt-p:toggle-preview'
    --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up'
    --bind 'alt-k:preview-up,alt-j:preview-down'
    --color 'pointer:red,marker:red'
  )

  local pkg_names
  pkg_names="$(rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort -u | fzf "${fzf_args[@]}")"

  if [[ -n $pkg_names ]]; then
    local -a pkgs
    mapfile -t pkgs <<< "$pkg_names"
    _omarchy_dnf remove -y "${pkgs[@]}" || return 1
  fi
  return 0
}

# omarchy-pkg-aur-add: the AUR is Arch-only; on Fedora install from dnf instead.
omarchy_pkg_aur_add() {
  omarchy_pkg_add "$@"
}

# omarchy-pkg-aur-install: the AUR is Arch-only; on Fedora use the dnf TUI.
omarchy_pkg_aur_install_tui() {
  omarchy_pkg_install_tui "$@"
}

# omarchy-pkg-aur-accessible: the AUR does not exist on Fedora.
omarchy_pkg_aur_accessible() {
  return 1
}
