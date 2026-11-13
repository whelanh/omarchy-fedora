#!/usr/bin/env bash
#
# Omarchy Quattro for Fedora - full updater
#
# Implements the "full target updater" from UPDATING.md (spec section 20):
#   1. refresh Fedora repository metadata (dnf makecache)
#   2. upgrade Fedora packages (dnf upgrade) — including the first-party
#      binaries from the whelanh/omarchy COPR, which are now shipped as RPMs
#   3. (optional) sync the Omarchy userspace to upstream quattro with
#      OMARCHY_FEDORA_UPDATE_UPSTREAM=1; otherwise re-apply what is committed
#   4. re-apply the userspace (tree + CLI wiring + compat shims)
#   5. run pending Omarchy migrations
#   6. upgrade mise-managed tools (as upstream's omarchy-update-mise does)
#   7. validate the installation
#
# For end users this is what `omarchy update` runs (installed by install.sh as a
# /usr/bin/omarchy-update shim). The live upstream pull needs a git checkout
# with the `upstream` remote plus the git-subtree package, and is opt-in; a
# non-git install refreshes the userspace from the quattro tarball instead (see
# UPDATING.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$SCRIPT_DIR/install.sh"
. "$SCRIPT_DIR/lib/pkg.sh"
. "$SCRIPT_DIR/lib/snapshot.sh"

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

  local file name ran=0 rc
  for file in "$mdir"/*.sh; do
    [ -f "$file" ] || continue
    name="$(basename "$file")"
    if [ -e "$state/$name" ]; then
      continue
    fi
    log "Running Fedora migration: $name"
    rc=0
    if (( EUID == 0 )); then
      bash "$file" || rc=$?
      if (( rc == 0 )); then
        mkdir -p "$state" && touch "$state/$name" || rc=1
      fi
    else
      sudo bash "$file" || rc=$?
      if (( rc == 0 )); then
        sudo mkdir -p "$state" && sudo touch "$state/$name" || rc=1
      fi
    fi
    ran=1
    case "$rc" in
      0) ;;
      # 75 (EX_TEMPFAIL): the script deliberately did nothing because its
      # precondition is not met yet (e.g. a replacement RPM is not published).
      # No marker is written, so the next update retries; this is not a failure.
      75) warn "migration $name deferred (will retry next update)" ;;
      *) warn "migration $name failed (will retry next update)" ;;
    esac
  done
  [ "$ran" = 1 ] || log "No pending Fedora migrations."
}

# Upgrade mise-managed tools ($HOME toolchain: coding agents, language runtimes).
# Upstream runs `omarchy-update-mise` on every `omarchy update`; mise's
# release-age cooldown otherwise holds tools back for days, and running the
# update is the user asking for current versions now, so the cooldown is
# overridden (MISE_MINIMUM_RELEASE_AGE=0). Tools are per-$HOME, so when the
# updater itself runs as root (`sudo ./fedora/scripts/update.sh`) this drops to
# the target account; otherwise the invoking user's own mise/HOME is already
# right. Best-effort: a tool that fails to build must not block the update.
omarchy_fedora_update_mise() {
  if ! command -v mise >/dev/null 2>&1; then
    log "mise not installed; skipping mise tools"
    return 0
  fi

  local -a runner=()
  if (( EUID == 0 )); then
    local user="${TARGET_USER:-${SUDO_USER:-}}"
    if [ -z "$user" ] || [ "$user" = root ]; then
      user="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)"
    fi
    if [ -z "$user" ]; then
      warn "no target user found; skipping mise tools"
      return 0
    fi
    if command -v runuser >/dev/null 2>&1; then
      runner=(runuser -u "$user" --)
    else
      runner=(sudo -u "$user")
    fi
  fi

  log "Updating mise-managed tools..."
  "${runner[@]}" env MISE_MINIMUM_RELEASE_AGE=0 mise upgrade \
    || warn "mise upgrade failed (continuing)"
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
# with a notice when snapper is absent or has no root config - a missing snapshot
# must never block the update.
#
# snapper metadata is root-only (/.snapshots is 0750), so detection runs through
# sudo when the updater is invoked as the desktop user, just like snapper itself.
_omarchy_snapshot_orphans_as_root() {
  if (( EUID == 0 )); then
    omarchy_snapshot_orphans
  else
    sudo bash -c "$(declare -f omarchy_snapshot_orphans)
omarchy_snapshot_orphans" 2>/dev/null || true
  fi
}

omarchy_fedora_snapshot() {
  local rootfs desc orphans="" nums="" cleanup="" n err rc=0
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

  # A subvolume deleted without its info.xml leaves snapper warning about the
  # same snapshot on every run. Report it up front, with the exact cleanup
  # command, instead of letting the raw "snapshot check failed" line stand
  # alone. Never delete automatically: confirm the subvolume is really gone.
  orphans="$(_omarchy_snapshot_orphans_as_root)"
  if [ -n "$orphans" ]; then
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      nums+="${nums:+ }$n"
      cleanup+=" /.snapshots/$n"
    done <<<"$orphans"
    warn "snapper has orphaned snapshot metadata: $nums"
    warn "  Their btrfs subvolumes are gone, so snapper skips them and repeats"
    warn "  'snapshot check failed' on every run. After confirming with"
    warn "  'sudo btrfs subvolume show /.snapshots/<num>/snapshot', remove them with:"
    warn "    sudo rm -rf$cleanup"
  fi

  log "Creating pre-update snapshot..."
  desc="omarchy update"
  err="$(mktemp)"
  if (( EUID == 0 )); then
    snapper --no-dbus -c root create -c number -d "$desc" >/dev/null 2>"$err" \
      && snapper --no-dbus -c root cleanup number >/dev/null 2>>"$err" || rc=$?
  else
    sudo snapper --no-dbus -c root create -c number -d "$desc" >/dev/null 2>"$err" \
      && sudo snapper --no-dbus -c root cleanup number >/dev/null 2>>"$err" || rc=$?
  fi
  if [ -s "$err" ]; then
    if [ -n "$orphans" ]; then
      # The warning is already explained above; drop just that repeated line.
      grep -vE 'snapshot check failed\. not adding snapshot [0-9]+$' "$err" >&2 || true
    else
      cat "$err" >&2
    fi
  fi
  rm -f "$err"
  if (( rc != 0 )); then
    warn "Pre-update snapshot failed (continuing without one)"
  fi
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

# 3 — optional live sync of the vendored upstream/ tree, then 4 — re-apply.
#
# The userspace is a *squashed* git subtree (the upstream-sync workflow adds it
# with `git subtree --squash`), so a live pull must use --squash too; a plain
# `git subtree pull` fails with "refusing to merge unrelated histories". It also
# needs the `git subtree` helper, which is the separate git-subtree package on
# Fedora, not part of stock git. Both made the default-on pull fail on ordinary
# machines, so the live pull is now opt-in (OMARCHY_FEDORA_UPDATE_UPSTREAM=1,
# matching UPDATING.md's "development sync") and we always re-apply whatever
# upstream/ is committed. End users' checkouts advance upstream/ by pulling the
# reviewed sync merge (or via the upstream-sync workflow), not by omarchy update
# rewriting it behind their back.
if [ "${OMARCHY_FEDORA_UPDATE_UPSTREAM:-0}" = "1" ] \
   && [ -d "$OMARCHY_ROOT/.git" ] \
   && (cd "$OMARCHY_ROOT" && git remote get-url upstream >/dev/null 2>&1); then
  if ! (cd "$OMARCHY_ROOT" && git subtree --help >/dev/null 2>&1); then
    warn "git-subtree is not installed; skipping the live upstream pull (dnf install git-subtree)"
  else
    log "Syncing the Omarchy userspace to upstream quattro (git subtree pull --squash)..."
    if ! (cd "$OMARCHY_ROOT" && git subtree pull --prefix upstream --squash upstream quattro \
            -m "chore(upstream): sync Omarchy quattro"); then
      warn "upstream pull failed (manual review required; see UPSTREAM.md)"
    fi
  fi
fi

if [ -d "$OMARCHY_ROOT/.git" ] || omarchy_fedora_sync_userspace_tarball; then
  log "Re-applying the Omarchy userspace (idempotent)..."
  bash "$INSTALL_SH" --update
else
  warn "userspace sync failed; continuing with Fedora packages only"
fi

# 5 — migrations. Upstream's `omarchy-migrate` runs Arch-specific pacman
# scripts, so we skip it; instead run our own Fedora-native migrations
# (fedora/migrations/*.sh) for package removals/replacements and distro-neutral
# config changes. See fedora/migrations/README.md.
omarchy_fedora_migrate

# 6 — mise-managed tools. Matches upstream, which always upgrades mise tools as
# part of `omarchy update` (omarchy-update-mise). Runs with the user's HOME so
# it updates their toolchain, not root's.
omarchy_fedora_update_mise

# 7 — validation (lightweight summary; install.sh --update already validates).
log "Update complete."
if [ -f /usr/share/omarchy/version ]; then
  log "Omarchy userspace version: $(cat /usr/share/omarchy/version)"
fi
