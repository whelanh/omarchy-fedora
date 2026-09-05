#!/usr/bin/env bash
#
# Omarchy Quattro for Fedora - full updater
#
# Implements the "full target updater" from UPDATING.md (spec section 20):
#   1. refresh Fedora repository metadata (dnf makecache)
#   2. upgrade Fedora packages (dnf upgrade) — including the first-party
#      binaries from the whelanh/omarchy COPR, which are now shipped as RPMs
#   3. sync the Omarchy userspace to the latest upstream quattro
#   4. re-apply the userspace (tree + CLI wiring + compat shims)
#   5. run pending Omarchy migrations
#   6. validate the installation
#
# For end users this is what `omarchy update` runs (installed by install.sh as a
# /usr/bin/omarchy-update shim). Steps 3-4 need a git checkout with the
# `upstream` remote; when absent they are skipped with a notice (see UPDATING.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$SCRIPT_DIR/install.sh"
. "$SCRIPT_DIR/lib/pkg.sh"

log() { printf '\033[1;34m[omarchy-update] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[omarchy-update] %s\033[0m\n' "$*" >&2; }

# Fedora-native migrations: timestamped *.sh scripts under fedora/migrations/
# that run ONCE (as root), tracked by a marker in /var/lib/omarchy-fedora/
# migrations. These cover what upstream's omarchy-migrate would do but is
# Arch-specific: package removals/replacements (dnf) and distro-neutral config
# migrations. A failed script leaves no marker, so it retries next update.
# See fedora/migrations/README.md.
omarchy_fedora_migrate() {
  local mdir="$OMARCHY_ROOT/fedora/migrations"
  local state="/var/lib/omarchy-fedora/migrations"
  [ -d "$mdir" ] || return 0

  local file name ran=0
  for file in "$mdir"/*.sh; do
    [ -f "$file" ] || continue
    name="$(basename "$file")"
    if [ -e "$state/$name" ]; then
      continue
    fi
    log "Running Fedora migration: $name"
    if (( EUID == 0 )); then
      bash "$file" && { mkdir -p "$state"; touch "$state/$name"; }
    else
      sudo bash "$file" && { sudo mkdir -p "$state"; sudo touch "$state/$name"; }
    fi && ran=1 || warn "migration $name failed (will retry next update)"
  done
  [ "$ran" = 1 ] || log "No pending Fedora migrations."
}

# Fetch the Omarchy userspace directly from GitHub (quattro branch) and rsync it
# into the checkout's vendored `upstream/` tree. Used when there is no git /
# `upstream` remote to subtree-pull from (e.g. the checkout was downloaded as a
# tarball). After this, `install.sh --update` copies the refreshed tree into
# /usr/share/omarchy and re-applies wiring. The tree is a rolling branch, so
# this is the live-source-of-truth path.
omarchy_fedora_sync_userspace_tarball() {
  local dest="$OMARCHY_ROOT/upstream"
  local url="https://github.com/omacom/omarchy/archive/refs/heads/quattro.tar.gz"
  local tmp srcdir rc
  tmp="$(mktemp -d)"
  log "Downloading the Omarchy userspace (quattro) from GitHub..."
  if ! curl -fsSL "$url" -o "$tmp/quattro.tar.gz"; then
    warn "download failed: $url"
    rm -rf "$tmp"
    return 1
  fi
  if ! tar xzf "$tmp/quattro.tar.gz" -C "$tmp"; then
    warn "failed to extract the downloaded tarball"
    rm -rf "$tmp"
    return 1
  fi
  srcdir="$tmp/omarchy-quattro"
  [ -d "$srcdir" ] || srcdir="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -1)"
  log "Syncing the userspace into $dest ..."
  mkdir -p "$dest"
  if (( EUID == 0 )); then
    rsync -a --delete "$srcdir"/ "$dest"/
  else
    sudo rsync -a --delete "$srcdir"/ "$dest"/
  fi
  rc=$?
  rm -rf "$tmp"
  return $rc
}

# Create a pre-update btrfs snapshot so a broken upgrade can be rolled back
# from the boot menu (snapper + grub-btrfs). Mirrors upstream's
# `omarchy-snapshot create` without depending on the upstream binary. Skipped
# silently when snapper is absent or has no root config - a missing snapshot
# must never block the update.
omarchy_fedora_snapshot() {
  local rootfs desc
  rootfs="$(findmnt -no FSTYPE / 2>/dev/null || true)"
  if [ "$rootfs" != "btrfs" ]; then
    return 0
  fi
  if ! omarchy_pkg_is_installed snapper; then
    log "No pre-update snapshot (snapper not installed)"
    return 0
  fi
  if [ ! -e /etc/snapper/configs/root ]; then
    log "No pre-update snapshot (no snapper root config)"
    return 0
  fi

  log "Creating pre-update snapshot..."
  desc="omarchy update"
  if (( EUID == 0 )); then
    snapper -c root create -c number -d "$desc" >/dev/null \
      && snapper -c root cleanup number >/dev/null
  else
    sudo snapper -c root create -c number -d "$desc" >/dev/null \
      && sudo snapper -c root cleanup number >/dev/null
  fi || warn "Pre-update snapshot failed (continuing without one)"
}

# 1 + 2 — Fedora packages (incl. first-party COPR RPMs).
# Best-effort: a package conflict (e.g. a transient COPR ABI mismatch such as a
# stale fc45 hyprland build) must not block the userspace sync or the Fedora
# migrations below. Without the || guards, `set -euo pipefail` would abort the
# entire update here, leaving the userspace stuck on an old snapshot.
log "Refreshing repository metadata and upgrading Fedora packages..."
omarchy_pkg_update || warn "dnf makecache failed; continuing"
omarchy_fedora_snapshot
omarchy_pkg_upgrade || warn "dnf upgrade failed (package conflicts or a transient repo issue); continuing with the userspace sync"

# 3 + 4 — Omarchy userspace.
if [ "${OMARCHY_FEDORA_UPDATE_UPSTREAM:-1}" != "1" ]; then
  log "userspace sync disabled (OMARCHY_FEDORA_UPDATE_UPSTREAM=0)"
elif [ -d "$OMARCHY_ROOT/.git" ] && (cd "$OMARCHY_ROOT" && git remote get-url upstream >/dev/null 2>&1); then
  log "Syncing the Omarchy userspace to upstream quattro (git subtree)..."
  if (cd "$OMARCHY_ROOT" && git subtree pull --prefix upstream upstream quattro); then
    log "Re-applying the Omarchy userspace (idempotent)..."
    bash "$INSTALL_SH" --update
  else
    log "upstream pull failed (manual review required; see UPSTREAM.md)"
  fi
else
  # Fallback: fetch the quattro tarball, refresh the vendored upstream/ tree,
  # then re-apply via install.sh --update (which copies it to /usr/share/omarchy).
  if omarchy_fedora_sync_userspace_tarball; then
    log "Re-applying the Omarchy userspace (idempotent)..."
    bash "$INSTALL_SH" --update
  else
    log "userspace sync via tarball failed; continuing with Fedora packages only"
  fi
fi

# 5 — migrations. Upstream's `omarchy-migrate` runs Arch-specific pacman
# scripts, so we skip it; instead run our own Fedora-native migrations
# (fedora/migrations/*.sh) for package removals/replacements and distro-neutral
# config changes. See fedora/migrations/README.md.
omarchy_fedora_migrate

# 6 — validation (lightweight summary; install.sh --update already validates).
log "Update complete."
if [ -f /usr/share/omarchy/version ]; then
  log "Omarchy userspace version: $(cat /usr/share/omarchy/version)"
fi
