#!/usr/bin/env bash
# Create the whelanh/omarchy COPR project that publishes the Omarchy
# first-party RPMs (fedora/rpm/*). Idempotent for the parts copr-cli exposes.
#
# Usage:
#   fedora/rpm/copr/create-project.sh                        # rawhide only
#   fedora/rpm/copr/create-project.sh fedora-44-x86_64 ...   # rawhide + listed
#   fedora/rpm/copr/create-project.sh --check                # describe project
#
# Requires:
#   - copr-cli: sudo dnf install -y copr-cli
#   - an authenticated session: `copr-cli login` with an API token generated at
#     https://copr.fedorainfracloud.org/api/  (writes ~/.config/copr)
#
# Design notes:
#   - Chroot fedora-rawhide-x86_64 matches the container + CI verification; it
#     is always enabled. Pass extra chroots (e.g. a new Fedora release) as args.
#   - The nett00n/hyprland COPR is registered as a *per-chroot* build-time
#     additional repo (one release-matched URL per chroot) because
#     hyprland-preview-share-picker needs gtk4-layer-shell-devel, which official
#     Fedora does not ship. A single project-level repo would be pinned to one
#     release and poison the other chroots (see fedora/mappings/repositories.yaml).
#   - COPR otherwise builds from our local/built-on-upload SRPMs (no VCS webhook).
set -euo pipefail

COPR="whelanh/omarchy"
DEFAULT_CHROOT="fedora-rawhide-x86_64"
HYPRLAND_BASE="https://download.copr.fedorainfracloud.org/results/nett00n/hyprland"
DESCRIPTION="Omarchy Quattro first-party packages (aether, cliamp, elsewhen, herdr, hyprland-preview-share-picker, omacalc, omacut, omawrite, owe, owe-lockfeed, tensaku, try, ttfx), source-built/repacked from fedora/rpm."
INSTRUCTIONS="Enabling the repo: sudo dnf copr enable ${COPR}; then: sudo dnf install aether cliamp elsewhen herdr hyprland-preview-share-picker omacalc omacut omawrite owe owe-lockfeed tensaku try ttfx"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
need copr-cli

if [ "${1:-}" = "--check" ]; then
  echo "== existing project =="
  copr-cli list --output-format text 2>/dev/null || copr-cli list 2>/dev/null
  exit 0
fi

# Chroots: explicit args (minus --check), else the default rawhide. Always
# keep rawhide enabled so it is never accidentally dropped.
chroots=()
for a in "$@"; do
  [ "$a" = "--check" ] && continue
  chroots+=("$a")
done
# ensure rawhide is present exactly once
filtered=()
for c in "${chroots[@]}"; do [ "$c" = "$DEFAULT_CHROOT" ] || filtered+=("$c"); done
chroots=("$DEFAULT_CHROOT" "${filtered[@]}")

echo "== creating COPR project: $COPR (chroots: ${chroots[*]}) =="
create_args=("$COPR")
for c in "${chroots[@]}"; do create_args+=(--chroot "$c"); done
copr-cli create "${create_args[@]}" \
  --description "$DESCRIPTION" \
  --instructions "$INSTRUCTIONS"

# Register the release-matched hyprland build repo on each chroot (project-level
# repos would leak across releases).
for c in "${chroots[@]}"; do
  echo "== build repo for $c: $HYPRLAND_BASE/$c/ =="
  copr-cli edit-chroot "$COPR/$c" --repos "$HYPRLAND_BASE/$c/"
done

echo "created $COPR"
echo
echo "Next steps:"
echo "  1. Sanity-check the chroots + build-repo settings:"
echo "       copr-cli get $COPR   (and copr-cli get-chroot $COPR/<chroot>)"
echo "  2. Authenticate/build:"
echo "       bash fedora/rpm/copr/submit-builds.sh"
echo "  See fedora/rpm/copr/README.md for the token flow and rebuild policy."
