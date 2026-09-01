#!/bin/bash
# omarchy-fedora dependency install helper
# Installs Fedora repositories and packages needed for Omarchy Quattro.
#
# Order matters:
#   1. base system packages (fedora official)
#   2. enable COPR / rpmfusion repositories first (packages may depend on them)
#   3. desktop packages (many from COPR)
#   4. optional packages on request

# Guard against multiple sourcing
if [ -n "${OMARCHY_FEDORA_DEPS_LIB:-}" ]; then return 0 2>/dev/null || exit 0; fi
OMARCHY_FEDORA_DEPS_LIB=1

# Source the dnf abstraction library.
# shellcheck source=lib/pkg.sh
. "$(dirname "${BASH_SOURCE[0]}")/pkg.sh"

OMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESOLVE="$OMARCHY_ROOT/fedora/scripts/lib/resolve.py"
REPOS_YAML="$OMARCHY_ROOT/fedora/mappings/repositories.yaml"
PACKAGES_DIR="$OMARCHY_ROOT/fedora/packages"

# ---------------------------------------------------------------------------
# Repository management
# ---------------------------------------------------------------------------

# Enable dnf-plugins-core / copr plugin (idempotent).
omarchy_fedora_repo_tools() {
  if ! command -v dnf >/dev/null 2>&1; then
    echo "omarchy: dnf not found" >&2
    return 1
  fi
  if ! rpm -q dnf-plugins-core >/dev/null 2>&1; then
    _omarchy_dnf install -y 'dnf-command(copr)' >/dev/null \
      || _omarchy_dnf install -y dnf-plugins-core >/dev/null
  fi
}

# Enable the mandatory COPR repositories listed in repositories.yaml.
# nett00n/hyprland supplies the Hyprland ecosystem; atim/* supplies CLI tools
# (lazygit, lazydocker, starship) that are not packaged in official Fedora.
omarchy_fedora_enable_coprs() {
  omarchy_fedora_repo_tools || return 1
  # Mandatory COPR repos
  for entry in nett00n/hyprland atim/lazygit atim/lazydocker atim/starship; do
    if ! omarchy_pkg_repo_enabled "copr:copr.fedorainfracloud.org:${entry//\//:}" \
       && ! omarchy_pkg_repo_enabled "${entry//\//:}"; then
      echo "omarchy: enabling COPR: $entry"
      omarchy_pkg_enable_repo copr "$entry" || return 1
    else
      echo "omarchy: COPR already enabled: $entry"
    fi
  done
}

# Enable optional COPR repos only when requested (the caller passes names).
omarchy_fedora_enable_optional_coprs() {
  local copr
  for copr in "$@"; do
    omarchy_pkg_enable_repo copr "$copr" || return 1
  done
}

# Fetch and enable an external RPM repo (a URL to a .repo file) via
# `dnf config-manager --add-repo`. Used for repos that are neither Fedora
# official nor COPR (currently: the upstream mise RPM repo). Idempotent.
omarchy_fedora_enable_external_repo() {
  local url="$1"
  local repo_name repo_file
  repo_name="$(basename "${url%%.repo*}")"
  repo_file="/etc/yum.repos.d/${repo_name}.repo"
  if [ -f "$repo_file" ]; then
    echo "omarchy: external repo already configured: $repo_name"
    return 0
  fi
  if ! command -v dnf >/dev/null 2>&1; then
    echo "omarchy: dnf not found" >&2
    return 1
  fi
  echo "omarchy: adding external repo: $url"
  # --add-repo fetches the .repo, enables it, and (for a fetch) installs the
  # repo GPG key; the URL is pinned to a trusted upstream in repositories.yaml.
  _omarchy_dnf config-manager --add-repo "$url" || return 1
  # sanity: the fetched repo file must actually contain a baseurl, so we don't
  # silently add an empty/broken repo.
  if ! grep -q '^\s*baseurl\s*=' "$repo_file"; then
    echo "omarchy: fetched repo $repo_file has no baseurl; removing it" >&2
    rm -f "$repo_file"
    return 1
  fi
  return 0
}

# Enable RPM Fusion (free + nonfree) via official release RPMs. Idempotent.
omarchy_fedora_enable_rpmfusion() {
  local rel
  rel="$(rpm -E %fedora)"
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    echo "omarchy: enabling RPM Fusion free"
    _omarchy_dnf install -y \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${rel}.noarch.rpm" \
      || return 1
  fi
  if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    echo "omarchy: enabling RPM Fusion nonfree"
    _omarchy_dnf install -y \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${rel}.noarch.rpm" \
      || return 1
  fi
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

# Install a category list file (fedora/packages/<name>.txt). Skips comments.
omarchy_fedora_install_list() {
  local list="$1"
  shift
  local extra=("$@")
  if [ ! -f "$list" ]; then
    echo "omarchy: package list not found: $list" >&2
    return 2
  fi
  local pkgs=()
  while IFS= read -r line; do
    line="${line%%#*}"          # strip comments
    line="${line//[[:space:]]/}" # strip whitespace
    [ -n "$line" ] && pkgs+=("$line")
  done < "$list"
  pkgs+=("${extra[@]}")
  if (( ${#pkgs[@]} > 0 )); then
    omarchy_pkg_install "${pkgs[@]}" || return 1
  fi
  return 0
}

# Install base system packages from the curated Fedora base manifest
# (fedora/packages/base.txt). base.txt is the authoritative install list; the
# resolver mapping (packages.yaml) is used for upstream-sync classification
# and is not the runtime install manifest.
omarchy_fedora_install_base() {
  # power-profiles-daemon provides ppd-service, which conflicts with tuned-ppd.
  # Several Fedora spins (e.g. Sway, Workstation) pre-install tuned/tuned-ppd,
  # so remove it first to avoid a hard transaction conflict.
  if rpm -q tuned-ppd >/dev/null 2>&1 || rpm -q tuned >/dev/null 2>&1; then
    echo "omarchy: removing tuned/tuned-ppd (conflicts with power-profiles-daemon)"
    omarchy_pkg_remove tuned-ppd tuned || true
  fi
  omarchy_fedora_install_list "$PACKAGES_DIR/base.txt" || return 1
}

# Install the Hyprland/Omarchy desktop packages.
# Requires COPR repos already enabled (omarchy_fedora_enable_coprs).
omarchy_fedora_install_desktop() {
  local -a desktop=()
  local -a copr_pkgs=()
  while IFS= read -r p; do [ -n "$p" ] && copr_pkgs+=("$p"); done \
    < <(python3 "$RESOLVE" --copr nett00n/hyprland)
  while IFS= read -r line; do
    line="${line%%#*}"; line="${line//[[:space:]]/}"
    [ -n "$line" ] && desktop+=("$line")
  done < "$PACKAGES_DIR/desktop.txt"
  desktop+=("${copr_pkgs[@]}")
  omarchy_pkg_install "${desktop[@]}" || return 1
  return 0
}

# Install applications category.
omarchy_fedora_install_applications() {
  omarchy_fedora_install_list "$PACKAGES_DIR/applications.txt" || return 1
}

# Install the first-party Omarchy binaries from the whelanh/omarchy COPR
# (aether, cliamp, herdr, hyprland-preview-share-picker, omacalc, omacut,
# omawrite, tensaku, tobi-try, ttfx). Requires the COPR enabled (install.sh
# does this in install_repos). The 10 are `source: copr` in packages.yaml;
# resolve.py --copr whelanh/omarchy emits the exact install set.
omarchy_fedora_install_firstparty() {
  local -a firstparty=()
  while IFS= read -r p; do [ -n "$p" ] && firstparty+=("$p"); done \
    < <(python3 "$RESOLVE" --copr whelanh/omarchy)
  if (( ${#firstparty[@]} == 0 )); then
    echo "omarchy: no first-party packages resolved from whelanh/omarchy" >&2
    return 0
  fi
  omarchy_pkg_install "${firstparty[@]}" || return 1
  return 0
}

# Install optional packages by category name (e.g. gaming, notes).
omarchy_fedora_install_optional() {
  local which="$1"; shift
  case "$which" in
    gaming)
      omarchy_fedora_enable_optional_coprs ferdiu/moonlight || return 1
      omarchy_pkg_install moonlight-qt || return 1
      ;;
    notes)
      omarchy_fedora_enable_optional_coprs kmf/Obsidian || return 1
      omarchy_pkg_install obsidian || return 1
      ;;
    asus)
      omarchy_fedora_enable_optional_coprs lukenukem/asus-linux || return 1
      omarchy_pkg_install asusctl || return 1
      ;;
    *)
      echo "omarchy: unknown optional group: $which" >&2
      return 2
      ;;
  esac
}
