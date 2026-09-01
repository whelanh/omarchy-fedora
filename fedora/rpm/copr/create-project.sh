#!/usr/bin/env bash
# Create the whelanh/omarchy COPR project that publishes the Omarchy
# first-party RPMs (fedora/rpm/*). Idempotent for the parts copr-cli exposes.
#
# Usage:
#   fedora/rpm/copr/create-project.sh          # create the project
#   fedora/rpm/copr/create-project.sh --check  # describe existing project
#
# Requires:
#   - copr-cli: sudo dnf install -y copr-cli
#   - an authenticated session: `copr-cli login` with an API token generated at
#     https://copr.fedorainfracloud.org/api/  (writes ~/.config/copr)
#
# Design notes:
#   - Chroot fedora-rawhide-x86_64 matches the container + CI verification.
#   - The nett00n/hyprland COPR is registered as a build-time additional repo
#     because hyprland-preview-share-picker + tensaku need gtk4-layer-shell-dev*,
#     which official Fedora does not ship (see fedora/mappings/repositories.yaml).
#   - COPR otherwise builds from our local/built-on-upload SRPMs (no VCS webhook).
set -euo pipefail

COPR="whelanh/omarchy"
CHROOT="fedora-rawhide-x86_64"
BUILD_REPO="https://download.copr.fedorainfracloud.org/results/nett00n/hyprland/${CHROOT}/"
DESCRIPTION="Omarchy Quattro first-party binaries (aether, cliamp, herdr, hyprland-preview-share-picker, omacalc, omacut, omawrite, tensaku, try, ttfx), source-built/repacked from fedora/rpm."
INSTRUCTIONS="Enabling the repo: sudo dnf copr enable ${COPR}; then: sudo dnf install aether cliamp herdr hyprland-preview-share-picker omacalc omacut omawrite tensaku try ttfx"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
need copr-cli

if [ "${1:-}" = "--check" ]; then
  echo "== existing project =="
  copr-cli list --output-format text 2>/dev/null || copr-cli list 2>/dev/null
  exit 0
fi

echo "== creating COPR project: $COPR =="
copr-cli create "$COPR" \
  --chroot "$CHROOT" \
  --repo "$BUILD_REPO" \
  --description "$DESCRIPTION" \
  --instructions "$INSTRUCTIONS"

echo "created $COPR"
echo
echo "Next steps:"
echo "  1. Sanity-check the chroot + build-repo settings:"
echo "       copr-cli modify $COPR --chroot ???   (edit interactively if needed)"
echo "  2. Authenticate/build:"
echo "       bash fedora/rpm/copr/submit-builds.sh"
echo "  See fedora/rpm/copr/README.md for the token flow and rebuild policy."