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

echo "== Mapping consistency: fedora/substitute base packages are installed =="
# A base package classified `fedora`/`substitute` must resolve to a Fedora
# package name that actually appears in an install manifest (base/desktop/
# applications). Otherwise it would silently never be installed - either the
# mapping points at a nonexistent package (e.g. `dua` instead of `dua-cli`) or
# the manifest is missing the entry. Offline proxy for "in the enabled repos".
t "fedora/substitute base targets are in the install manifests" python3 -c "
import glob, yaml
installed = set()
for path in glob.glob('fedora/packages/*.txt'):
    for line in open(path):
        line = line.split('#')[0].strip()
        if line:
            installed.add(line)
packages = yaml.safe_load(open('fedora/mappings/packages.yaml'))['packages']
missing = []
for line in open('upstream/install/omarchy-base.packages'):
    name = line.split('#')[0].strip()
    if not name:
        continue
    entry = packages.get(name)
    if entry and entry.get('source') in ('fedora', 'substitute') and entry.get('package'):
        if entry['package'] not in installed:
            missing.append((name, entry['package']))
assert not missing, 'mapped but not installed: %r' % missing
"

echo "== First-party RPM scaffold: manifest + spec + build helper =="
t "fedora/rpm/manifest.yaml parses" python3 -c "
import glob, os, yaml
d = yaml.safe_load(open('fedora/rpm/manifest.yaml'))
assert 'packages' in d
for name, p in d['packages'].items():
    for k in ('repo','language','build','binary','license','status'):
        assert k in p, (name, k)
    assert os.path.isfile(f'fedora/rpm/{name}/{name}.spec'), f'missing spec {name}'
specs = sorted(os.path.basename(os.path.dirname(s)) for s in glob.glob('fedora/rpm/*/*.spec'))
orphans = [s for s in specs if s not in d['packages']]
assert not orphans, f'specs without a manifest entry: {orphans}'
"
# Every manifest package must have a matching <pkg>/<pkg>.spec.
t "build-rpm.sh bash -n" bash -n fedora/rpm/build-rpm.sh
t "build-in-container.sh bash -n" bash -n fedora/rpm/build-in-container.sh
t "build-rpm-in-ci.sh bash -n" bash -n fedora/rpm/build-rpm-in-ci.sh
t "install-rpms.sh bash -n" bash -n fedora/rpm/install-rpms.sh
t "vendor-rust.sh bash -n" bash -n fedora/rpm/vendor-rust.sh
t "copr/create-project.sh bash -n" bash -n fedora/rpm/copr/create-project.sh
t "copr/submit-builds.sh bash -n" bash -n fedora/rpm/copr/submit-builds.sh
t "copr/check-updates.sh bash -n" bash -n fedora/rpm/copr/check-updates.sh
for pkg in $(python3 -c "
import yaml; d=yaml.safe_load(open('fedora/rpm/manifest.yaml'))
print(' '.join(sorted(d['packages'].keys())))
"); do
  t "spec: $pkg" test -f "fedora/rpm/$pkg/$pkg.spec"
  # every spec must declare Name equal to the dir name and a valid changelog
  t "spec name/date: $pkg" python3 -c "
import re
spec = open('fedora/rpm/$pkg/$pkg.spec').read()
assert re.search(r'^Name:\\s+\\S+', spec, re.M), 'missing Name'
assert re.search(r'^\\* [A-Z][a-z]{2} [A-Z][a-z]{2} [0-9]{2} [0-9]{4} whelanh', spec, re.M), 'bad changelog date'
"
  # every manifest version must match its spec's Version:. Nothing auto-syncs
  # manifest.yaml, so a bumped spec with a stale manifest otherwise drifts
  # silently (check-updates.sh would keep reporting the package OUTDATED).
  t "manifest/spec version: $pkg" python3 -c "
import re, yaml
name = '$pkg'
spec = open('fedora/rpm/$pkg/$pkg.spec').read()
m = re.search(r'^Version:\\s*(\\S+)', spec, re.M)
man = yaml.safe_load(open('fedora/rpm/manifest.yaml'))['packages'][name].get('version')
assert m and str(m.group(1)) == str(man), 'drift'
"
done

echo "== First-party shell plugins install where the shell scans =="
# The shell scans OMARCHY_PATH/shell/plugins for first-party plugins
# (upstream/shell/shell.qml: firstPartyPluginsDir). An RPM that installs a
# plugin under OMARCHY_PATH/plugins instead is never discovered, which silently
# leaves a default bar widget (e.g. elsewhen) off the bar. Guard the spec and
# the migration that places it against the same drift.
t "elsewhen spec installs under shell/plugins" python3 -c "
import re
spec = open('fedora/rpm/elsewhen/elsewhen.spec').read()
assert re.search(r'%{_datadir}/omarchy/shell/plugins/omacom\.elsewhen', spec), \\
    'elsewhen must install under shell/plugins'
assert not re.search(r'%{_datadir}/omarchy/plugins/', spec), \\
    'elsewhen must not install under OMARCHY_PATH/plugins'
"
t "elsewhen migration probes shell/plugins" python3 -c "
import glob
migs = glob.glob('fedora/migrations/*-elsewhen-plugin.sh')
assert len(migs) == 1, migs
mig = open(migs[0]).read()
assert '/usr/share/omarchy/shell/plugins/omacom.elsewhen' in mig, \\
    'elsewhen migration must probe shell/plugins'
"

echo
echo "== Result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] || exit 1
