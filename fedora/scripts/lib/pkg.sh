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

# --- is_installed ---------------------------------------------------------
# Success (0) if the single named package is installed, failure otherwise.
omarchy_pkg_is_installed() {
  local pkg
  pkg="$(omarchy_pkg_normalize "$1")" || return 2
  rpm -q "$pkg" >/dev/null 2>&1
}

# --- install --------------------------------------------------------------
# Installs the named packages if any are missing. Idempotent: returns success
# if all are already installed without invoking dnf.
omarchy_pkg_install() {
  local missing=() pkg
  for pkg in "$@"; do
    if ! omarchy_pkg_is_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    return 0
  fi

  _omarchy_dnf install -y --skip-unavailable "${missing[@]}"
  local rc=$?

  # Distinguish package-not-found from transaction failure. dnf returns 1
  # for "no match for argument"; --skip-unavailable turns those into warnings
  # so a single stale package name cannot abort the entire transaction.
  if (( rc != 0 )); then
    echo "omarchy: dnf install failed for: ${missing[*]}" >&2
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
# Remove the named packages only if installed. Idempotent.
omarchy_pkg_remove() {
  local installed=() pkg
  for pkg in "$@"; do
    if omarchy_pkg_is_installed "$pkg"; then
      installed+=("$pkg")
    fi
  done

  if (( ${#installed[@]} == 0 )); then
    return 0
  fi

  _omarchy_dnf remove -y "${installed[@]}"
}

# --- update (refresh metadata) --------------------------------------------
omarchy_pkg_update() {
  _omarchy_dnf makecache
}

# --- upgrade (full system upgrade) ----------------------------------------
omarchy_pkg_upgrade() {
  _omarchy_dnf upgrade -y
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
