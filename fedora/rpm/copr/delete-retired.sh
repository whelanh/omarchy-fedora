#!/usr/bin/env bash
# Remove retired first-party packages from the whelanh/omarchy COPR.
#
# Retiring a package (deleting fedora/rpm/<pkg>/ + its manifest.yaml entry) stops
# new builds — the rest of the COPR tooling only touches `status: verified`
# packages — but the COPR still holds the source package and its build history,
# so `dnf` users keep seeing it. This deletes the packages named in
# fedora/rpm/copr/retired-packages.conf.
#
# Usage:
#   fedora/rpm/copr/delete-retired.sh            # delete them
#   fedora/rpm/copr/delete-retired.sh --dry-run  # show what would be deleted
#
# Requires copr-cli + login (see README.md). Idempotent: a package already
# absent from the project is reported and skipped, not an error. Exit status is
# 0 when everything is already gone (or --dry-run), 1 if a delete failed.
set -euo pipefail

COP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF="$COP_DIR/retired-packages.conf"
COPR="whelanh/omarchy"
DRY_RUN=0

case "${1:-}" in
  --dry-run|-n) DRY_RUN=1 ;;
  -h|--help) echo "usage: $0 [--dry-run]"; exit 0 ;;
  "") ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

[ -f "$CONF" ] || { echo "no $CONF" >&2; exit 0; }
command -v copr-cli >/dev/null 2>&1 || { echo "missing required tool: copr-cli" >&2; exit 2; }
command -v python3  >/dev/null 2>&1 || { echo "missing required tool: python3"  >&2; exit 2; }

mapfile -t names < <(sed 's/#.*//' "$CONF" | awk 'NF' | sort -u)
if [ "${#names[@]}" -eq 0 ]; then
  echo "no retired packages listed in $CONF"
  exit 0
fi

# Which packages the project currently has, so deleting an already-gone package
# is a no-op rather than an error (keeps re-runs idempotent). Skipped on
# --dry-run so a preview needs no login/network.
present=""
if [ "$DRY_RUN" != 1 ]; then
  present="$(copr-cli list-packages --output-format json "$COPR" 2>/dev/null)" || {
    echo "cannot list packages in $COPR (run 'copr-cli login' first)" >&2; exit 1; }
fi

# list-packages JSON is an array of package objects, so membership must look at
# each object's "name" (a bare `name in list` compares against the dicts and is
# never true, which silently skipped every delete).
has() {
  python3 -c 'import json,sys; print("yes" if any(p.get("name")==sys.argv[1] for p in json.load(sys.stdin)) else "no")' \
    "$1" <<<"$present"
}

rc=0
for name in "${names[@]}"; do
  if [ "$DRY_RUN" = 1 ]; then
    echo "would delete: $name"
    continue
  fi
  if [ "$(has "$name")" = no ]; then
    echo "already absent: $name"
    continue
  fi
  echo "== deleting $name from $COPR =="
  copr-cli delete-package --name "$name" "$COPR" || { echo "failed to delete $name" >&2; rc=1; }
done
exit "$rc"
