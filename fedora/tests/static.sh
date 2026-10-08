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

echo "== Menu package translation map =="
# The SUPER+SPACE Install rows call omarchy-pkg-* with Arch/AUR names; the map
# (fedora/mappings/menu-packages.conf) translates them to Fedora strategies.
t "menu-packages.conf parses" python3 -c "
seen = {}
valid = {'fedora', 'copr', 'repo', 'rpm', 'flatpak', 'unavailable'}
for i, line in enumerate(open('fedora/mappings/menu-packages.conf'), 1):
    line = line.split('#')[0].strip()
    if not line:
        continue
    parts = line.split('|')
    assert len(parts) == 7, ('bad column count', i, line)
    name, src, pkgs, repo, cmd, desktop, fallback = parts
    assert name and ' ' not in name, ('bad name', i, line)
    assert src in valid, ('bad source', i, line)
    assert name not in seen, ('duplicate', name)
    seen[name] = src
    if src in ('fedora', 'copr', 'repo', 'rpm'):
        assert pkgs, ('missing package', name)
    if src == 'copr':
        assert repo and '/' in repo, ('missing copr repo', name)
    if src in ('repo', 'rpm'):
        assert repo.startswith('http'), ('missing url', name)
    if src == 'flatpak':
        assert pkgs and '.' in pkgs, ('bad flatpak app id', name)
    if fallback:
        assert '.' in fallback, ('bad fallback id', name)
assert seen, 'empty map'
print(len(seen), 'menu entries')
"
t "shim translates a Flathub app" bash -c '
  . fedora/scripts/lib/pkg.sh
  [[ "$(_omarchy_pkg_resolve signal-desktop)" == "flatpak|org.signal.Signal||signal-desktop|signal-desktop.desktop|" ]]
'
t "shim carries a native fallback" bash -c '
  . fedora/scripts/lib/pkg.sh
  [[ "$(_omarchy_pkg_resolve google-chrome)" == "rpm|google-chrome-stable|https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm|google-chrome-stable|google-chrome.desktop|com.google.Chrome" ]]
'
t "shim translates a Fedora name mismatch" bash -c '
  . fedora/scripts/lib/pkg.sh
  [[ "$(_omarchy_pkg_resolve vim)" == "fedora|vim-enhanced||||" ]]
'
t "shim passes through unmapped names" bash -c '
  . fedora/scripts/lib/pkg.sh
  [[ "$(_omarchy_pkg_resolve tailscale)" == "fedora|tailscale||||" ]]
'

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

echo "== Installer SELinux + update-window hygiene =="
# `cp -a` carries the checkout's user_home_t label onto system paths, which
# confines readers like sddm (xdm_t) and udevd (udev_t) out. install.sh must
# relabel what it copies, and the tree copy must skip unchanged files so a
# no-op update does not make Hyprland reload (and read a file mid-write).
t "install.sh relabels copied system paths" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'restorecon_paths()' in src, 'missing restorecon_paths helper'
assert 'restorecon -R' in src, 'restorecon_paths must call restorecon'
assert src.count('restorecon_paths') >= 2, 'restorecon_paths must be defined and called'
"
t "tree copy skips unchanged files (no per-update reload)" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'cp -au \"\$UPSTREAM\"/*' in src, 'install_omarchy_tree must use cp -au'
"

echo "== Installer preselects the Omarchy SDDM session =="
# Upstream's Omarchy greeter theme has no session picker and reads the username
# from /var/lib/sddm/state.conf; without seeding [Last] a converted machine logs
# back into its previous session (Sway/GNOME). Guard the default-session seed and
# its call from main().
t "install.sh seeds /var/lib/sddm/state.conf for Omarchy" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'configure_sddm_login()' in src, 'missing configure_sddm_login helper'
assert '/var/lib/sddm' in src, 'must write SDDM state under /var/lib/sddm'
assert 'Session=omarchy.desktop' in src, 'must preselect the omarchy session'
assert 'User=%s' in src, 'must preselect the target user'
assert src.count('configure_sddm_login') >= 2, 'configure_sddm_login must be defined and called'
"

echo "== Installer rewrites fingerprint setup onto dnf =="
# Upstream's omarchy-setup-security-fingerprint installs libfprint-git/fprintd
# with raw pacman. install.sh must replace it with a generated override that
# uses the omarchy-pkg-* (dnf) shims and the Fedora package names, including the
# separate fprintd-pam package that ships pam_fprintd.so.
t "install.sh rewrites fingerprint setup for Fedora" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'install_omarchy_fingerprint_shim()' in src, 'missing fingerprint shim helper'
assert 'fprintd-pam' in src, 'must install the Fedora PAM package'
assert 'omarchy-pkg-add' in src, 'must install via the dnf shim'
assert 'pacman -S' in src, 'rewrite must target the pacman install line'
assert src.count('install_omarchy_fingerprint_shim') >= 2, 'fingerprint shim must be defined and called'
"

echo "== Installer masks KDE's xwaylandvideobridge autostart =="
# On a KDE base, org.kde.xwaylandvideobridge autostarts under Hyprland (its
# .desktop lacks OnlyShowIn=KDE) and paints an unclosable black Xwayland window.
# install.sh must mask it with a user-level Hidden=true override.
t "install.sh masks xwaylandvideobridge autostart" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'org.kde.xwaylandvideobridge.desktop' in src, 'must name the leaking autostart entry'
assert '/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop' in src, 'must gate on the KDE-provided file'
assert '.config/autostart/org.kde.xwaylandvideobridge.desktop' in src, 'must write the user override'
assert 'Hidden=true' in src, 'override must set Hidden=true'
"

echo "== Installer takes over the display manager (GNOME/GDM base) =="
# On Fedora Workstation GDM owns display-manager.service, so `systemctl enable
# sddm` fails and the Omarchy greeter never appears. install.sh must disable the
# other DMs first.
t "install.sh disables competing DMs before enabling SDDM" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert '_enable_display_manager()' in src, 'missing _enable_display_manager helper'
assert 'gdm.service' in src and '_systemctl_disable' in src, 'must disable GDM'
assert src.count('_enable_display_manager') >= 2, '_enable_display_manager must be defined and called'
assert 'display-manager.service' in src, 'must account for the display-manager alias'
"

echo "== Userspace update: squashed subtree + opt-in live pull =="
# upstream/ is a --squash subtree, so a plain `git subtree pull` fails with
# "refusing to merge unrelated histories"; it also needs the separate
# git-subtree package. update.sh must use --squash, gate the live pull behind
# OMARCHY_FEDORA_UPDATE_UPSTREAM=1, and check for git-subtree.
t "update.sh pulls the subtree with --squash" python3 -c "
src = open('fedora/scripts/update.sh').read()
assert 'git subtree pull --prefix upstream --squash upstream quattro' in src, 'live pull must use --squash'
assert 'git subtree --help' in src, 'must check git-subtree availability'
assert 'OMARCHY_FEDORA_UPDATE_UPSTREAM:-0' in src, 'live pull must be opt-in'
"

echo "== elsewhen migration uses the target user's runtime dir =="
# The migration runs as root (via sudo) and previously trusted XDG_RUNTIME_DIR
# from the environment. When that was root's /run/user/0 (no session), the shell
# ping went to the wrong socket and the migration wrongly reported no running
# shell. It must derive the runtime dir from the target user's uid.
t "elsewhen migration targets /run/user/\$uid" python3 -c "
src = open('fedora/migrations/1790092003-elsewhen-plugin.sh').read()
assert 'runtime=\"/run/user/\$uid\"' in src, 'must use the target uid runtime dir'
assert 'XDG_RUNTIME_DIR:-' not in src, 'must not trust the inherited XDG_RUNTIME_DIR'
assert 'DBUS_SESSION_BUS_ADDRESS' in src, 'must export the target session bus'
"

echo
echo "== Result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] || exit 1
