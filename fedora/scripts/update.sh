#!/bin/bash
#
# Omarchy Quattro for Fedora - update
#
# Updates the Fedora packages and re-synces the vendored upstream Omarchy
# tree to the latest upstream quattro (if run from the development checkout).
#
# For end users this is a thin wrapper over the Fedora-native update:
#   1. Refresh dnf metadata
#   2. Upgrade Fedora packages
#
# When OMARCHY_FEDORA_UPDATE_UPSTREAM=1 and we are in a git checkout, also
# pull the latest upstream quattro subtree and re-install the Omarchy tree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/lib/pkg.sh"

log() { printf '\033[1;34m[omarchy-update] %s\033[0m\n' "$*"; }

log "Updating Fedora package metadata and packages..."
omarchy_pkg_update
omarchy_pkg_upgrade

if [ "${OMARCHY_FEDORA_UPDATE_UPSTREAM:-0}" = "1" ] && [ -d "$OMARCHY_ROOT/.git" ]; then
  log "Pulling latest upstream Omarchy quattro subtree..."
  if (cd "$OMARCHY_ROOT" && git remote get-url upstream >/dev/null 2>&1); then
    (cd "$OMARCHY_ROOT" && git subtree pull --prefix upstream upstream quattro) \
      || log "upstream pull deferred (manual review required; see UPSTREAM.md)"
  else
    log "no 'upstream' remote configured; skipping upstream sync"
  fi
fi

log "Update complete."
