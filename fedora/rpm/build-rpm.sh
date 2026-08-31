#!/usr/bin/env bash
# Build one of the Omarchy first-party RPMs from fedora/rpm/.
#
# Usage:
#   fedora/rpm/build-rpm.sh <pkg>          # build one package
#   fedora/rpm/build-rpm.sh --all          # build every 'ready' package
#
# Requires rpm-build + mock (or rpmbuild available as root). Each package lives
# in <pkg>/<pkg>.spec. Sources are downloaded by the spec (Source URLs).
set -euo pipefail

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SELF/manifest.yaml"

need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }
die() { echo "error: $*" >&2; exit 1; }

# fetch a field from the YAML manifest for a package
manifest_field() {
  python3 - "$MANIFEST" "$1" "$2" <<'PY'
import sys, yaml
manifest, pkg, field = sys.argv[1], sys.argv[2], sys.argv[3]
data = yaml.safe_load(open(manifest))
print(data["packages"][pkg].get(field, "") or "")
PY
}

build_one() {
  local pkg="$1"
  [ -f "$SELF/$pkg/$pkg.spec" ] || die "no spec for package: $pkg"
  local status
  status="$(manifest_field "$pkg" status)"
  if [ "$status" = "blocked" ]; then
    echo "skipping $pkg: status=blocked (see fedora/rpm/README.md)"
    return 0
  fi

  # prepare the rpmbuild tree
  local topdir="$HOME/rpmbuild" pkg_topdir="$topdir/BUILD/$pkg"
  mkdir -p "$topdir"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

  # use mock if available (recommended); fall back to rpmbuild as root
  if command -v mock >/dev/null 2>&1; then
    echo "building $pkg with mock (fedora-rawhide-x86_64)..."
    mock -r fedora-rawhide-x86_64 --buildsrpm \
      --spec "$SELF/$pkg/$pkg.spec" \
      --sources "$topdir/SOURCES" --resultdir "$topdir/SRPMS"
    echo "built SRPM for $pkg — run: mock -r fedora-rawhide-x86_64 rebuild <srpm>"
  else
    need rpmbuild
    [ "$(id -u)" = 0 ] || die "rpmbuild as non-root requires mock; run with sudo or install mock"
    echo "building $pkg with rpmbuild..."
    rpmbuild --define "_topdir $topdir" \
      -ba "$SELF/$pkg/$pkg.spec"
  fi
  echo "built $pkg OK"
}

if [ "${1:-}" = "--all" ]; then
  # iterate every directory in fedora/rpm that contains a .spec
  for dir in "$SELF"/*/; do
    pkg="$(basename "$dir")"
    [ -f "$dir/$pkg.spec" ] && build_one "$pkg"
  done
elif [ -z "${1:-}" ]; then
  die "usage: build-rpm.sh <pkg> | --all"
else
  build_one "$1"
fi
