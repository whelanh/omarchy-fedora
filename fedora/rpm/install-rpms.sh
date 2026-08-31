#!/usr/bin/env bash
# Install the verified first-party Omarchy RPMs that were built locally.
#
# Expects the RPMs to have been produced by:
#   sudo bash fedora/rpm/build-rpm-in-ci.sh     (in-VM: /tmp/rpmbuild-<pkg>)
#   bash fedora/rpm/build-in-container.sh <pkg> (host: no artifacts exported)
#
# Usage:
#   sudo fedora/rpm/install-rpms.sh [topdir]
#
#   topdir  base directory containing per-package <pkg>/RPMS/x86_64 trees
#           (default: /tmp/rpmbuild)
#
# For each manifest package with status 'verified', the script locates the
# built .rpm (by the SPEC Name, e.g. tobi-try -> try) and installs it with
# dnf. Packages whose RPM is missing are skipped with a warning.
set -euo pipefail

RPM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$RPM_DIR/manifest.yaml"

# topdir holds <pkg>/RPMS/<arch>/*.rpm; build-rpm-in-ci.sh uses /tmp/rpmbuild-<pkg>,
# so default to /tmp/rpmbuild (each package dir is /tmp/rpmbuild-<pkg>).
BASE="${1:-/tmp/rpmbuild}"

need_root() {
  [ "$(id -u)" = 0 ] || { echo "error: run with sudo (dnf install needs root)" >&2; exit 1; }
}

# read a SPEC field (Name) from a package's spec
spec_name() {
  python3 - "$RPM_DIR/$1/$1.spec" <<'PY'
import re,sys
print(re.search(r'^Name:\s*(\S+)', open(sys.argv[1]).read(), re.M).group(1))
PY
}

main() {
  need_root

  local -a verified=()
  while IFS= read -r pkg; do
    verified+=("$pkg")
  done < <(python3 - "$MANIFEST" <<'PY'
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
print('\n'.join(sorted(p for p,v in d['packages'].items() if v['status']=='verified')))
PY
)

  if [ "${#verified[@]}" -eq 0 ]; then
    echo "no verified packages; nothing to install"
    exit 0
  fi

  local -a to_install=()
  local missing=()

  for pkg in "${verified[@]}"; do
    local name
    name="$(spec_name "$pkg")"
    # match either <topdir>/<pkg>/RPMS/... or <topdir>-<pkg>/RPMS/... layout
    local found=""
    for d in "$BASE/$pkg" "$BASE-$pkg"; do
      if [ -d "$d/RPMS" ]; then
        found="$(find "$d/RPMS" -name "$name-*.rpm" -type f 2>/dev/null | head -1 || true)"
        [ -n "$found" ] && break
      fi
    done
    if [ -n "$found" ]; then
      to_install+=("$found")
    else
      missing+=("$pkg")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "warning: no built RPM found for: ${missing[*]}"
    echo "         build them first with: sudo bash fedora/rpm/build-rpm-in-ci.sh"
  fi

  if [ "${#to_install[@]}" -eq 0 ]; then
    echo "error: nothing to install" >&2
    exit 1
  fi

  echo "installing:"
  printf '  %s\n' "${to_install[@]}"
  dnf -y install "${to_install[@]}"

  echo
  echo "installed. smoke-test:"
  for pkg in "${verified[@]}"; do
    local name
    name="$(spec_name "$pkg")"
    if command -v "$name" >/dev/null 2>&1; then
      echo "  OK: $name"
    else
      echo "  MISSING on PATH: $name"
    fi
  done
}

main "$@"
