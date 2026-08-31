#!/bin/bash
#
# Omarchy Quattro for Fedora - static test suite
#
# These tests run WITHOUT a Fedora system (offline): they validate shell
# syntax, YAML parseability, resolver output, and mapping consistency.
# They are safe to run in CI and in any environment.
#
# Requires: bash, python3, PyYAML.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0

ok()   { printf '\033[32m  PASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '\033[31m  FAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

t() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi
}

echo "== Shell syntax =="
for f in fedora/scripts/bootstrap.sh fedora/scripts/install.sh \
         fedora/scripts/update.sh fedora/scripts/uninstall.sh; do
  t "bash -n $f" bash -n "$f"
done
for f in fedora/scripts/lib/*.sh; do
  t "bash -n $f" bash -n "$f"
done

echo "== YAML mapping parses =="
t "packages.yaml parses" python3 -c "import yaml; d=yaml.safe_load(open('fedora/mappings/packages.yaml')); assert 'packages' in d"
t "repositories.yaml parses" python3 -c "import yaml; d=yaml.safe_load(open('fedora/mappings/repositories.yaml')); assert 'repositories' in d"

echo "== Resolver =="
t "resolve --source fedora" python3 fedora/scripts/lib/resolve.py --source fedora
t "resolve --build stable" python3 fedora/scripts/lib/resolve.py --build

echo "== Mapping consistency: every upstream base package is classified =="
# Every package in omarchy-base.packages must appear in packages.yaml.
while IFS= read -r pkg; do
  pkg="${pkg%%#*}"; pkg="${pkg//[[:space:]]/}"
  [ -n "$pkg" ] || continue
  t "mapped: $pkg" python3 fedora/scripts/lib/resolve.py --package "$pkg"
done < upstream/install/omarchy-base.packages

echo
echo "== Result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] || exit 1
