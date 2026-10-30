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
for f in fedora/migrations/*.sh; do
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

echo "== Retired packages =="
# Upstream drops packages over time; omarchy update must converge, not just add.
t "retired-packages.conf parses" python3 -c "
seen = set()
for i, line in enumerate(open('fedora/mappings/retired-packages.conf'), 1):
    line = line.split('#')[0].strip()
    if not line:
        continue
    assert ' ' not in line, ('space in name', i, line)
    assert line not in seen, ('duplicate', line)
    seen.add(line)
print(len(seen), 'retired packages')
"
t "retired lookup works" bash -c "
  . fedora/scripts/lib/deps.sh
  omarchy_fedora_is_retired clang && ! omarchy_fedora_is_retired bash
"
t "openai-codex-bin retired (spec gone, list + manifest)" python3 -c "
import os, yaml
assert not os.path.isdir('fedora/rpm/openai-codex-bin'), 'spec dir must be gone'
names = [l.split('#')[0].strip() for l in open('fedora/mappings/retired-packages.conf')]
assert 'openai-codex-bin' in names, 'must be in retired-packages.conf'
man = yaml.safe_load(open('fedora/rpm/manifest.yaml'))['packages']
assert 'openai-codex-bin' not in man, 'must not be in the RPM manifest'
assert 'openai-codex-desktop' in man, 'the ChatGPT desktop GUI must stay'
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
t "copr/delete-retired.sh bash -n" bash -n fedora/rpm/copr/delete-retired.sh
# The COPR keeps retired packages until explicitly deleted; retired-packages.conf
# drives delete-retired.sh. Guard that the packages we retired are listed.
t "copr/retired-packages.conf lists retired COPR packages" python3 -c "
names = [l.split('#')[0].strip() for l in open('fedora/rpm/copr/retired-packages.conf') if l.split('#')[0].strip()]
assert 'elsewhen' in names, 'elsewhen must be listed for COPR deletion'
assert 'openai-codex-bin' in names, 'openai-codex-bin must be listed for COPR deletion'
"
# auto-update.sh can prune those packages from the COPR as part of its run.
t "auto-update.sh supports --prune-retired" python3 -c "
s = open('fedora/rpm/copr/auto-update.sh').read()
assert '--prune-retired' in s, 'flag missing'
assert 'delete-retired.sh' in s, 'prune must call delete-retired.sh'
"
# A package can be pinned at its packaged version with `hold:` while upstream's
# new release needs a dependency we cannot get yet (titlebars 0.3.0 needs
# Hyprland 0.57 headers; nett00n/hyprland still ships 0.56.2). Both the updater
# and the drift report must honour it, otherwise every run re-bumps the package
# and the COPR build fails again.
t "manifest holds carry a reason" python3 -c "
import yaml
d = yaml.safe_load(open('fedora/rpm/manifest.yaml'))['packages']
for n, p in d.items():
    if 'hold' in p:
        assert isinstance(p['hold'], str) and p['hold'].strip(), n
"
t "auto-update.sh skips held packages" python3 -c "
s = open('fedora/rpm/copr/auto-update.sh').read()
assert 'if n in held' in s, 'updater must skip hold: packages'
"
t "check-updates.sh marks held packages HELD" python3 -c "
s = open('fedora/rpm/copr/check-updates.sh').read()
assert 'HELD' in s and 'hold' in s, 'drift report must mark holds'
"
# Without a token the report hits GitHub's 60 req/hour unauthenticated limit
# (~2 per upstream repo) and prints (unknown) for everything.
t "check-updates.sh honours GITHUB_TOKEN" python3 -c "
s = open('fedora/rpm/copr/check-updates.sh').read()
assert 'GITHUB_TOKEN' in s and 'Authorization' in s, 'token support missing'
"
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

echo "== omarchy-screensaver binary path =="
# Omarchy's bin/omarchy-launch-screensaver execs the literal path
# /usr/lib/omarchy-screensaver/omarchy-screensaver. Arch has no libexec split, so
# upstream packages it under /usr/lib; Fedora's %{_libexecdir} is /usr/libexec,
# and 1.3.1-1 shipped the binary there, where the launcher never looks. Guard
# the destination (and cross-check the launcher once the vendored tree has it).
t "screensaver installs outside %{_libexecdir}" python3 -c "
import re
spec = open('fedora/rpm/omarchy-screensaver/omarchy-screensaver.spec').read()
body = spec.split('%install', 1)[1].split('%changelog')[0]
# comments may mention the macro freely; only real directives count
code = '\n'.join(l for l in body.splitlines() if not l.lstrip().startswith('#'))
dest = '%{_prefix}/lib/omarchy-screensaver/omarchy-screensaver'
assert '%{_libexecdir}' not in code, 'libexecdir is /usr/libexec on Fedora; launcher execs /usr/lib/...'
assert code.count(dest) >= 2, 'install + %files must both use ' + dest
try:
    launcher = open('upstream/bin/omarchy-launch-screensaver').read()
except FileNotFoundError:
    launcher = ''
# cross-check once the vendored tree carries upstream's exec-style launcher
for m in re.finditer(r'^exec (/\S+)', launcher, re.M):
    assert m.group(1) == '/usr/lib/omarchy-screensaver/omarchy-screensaver', m.group(1)
"
echo "== Elsewhen retired upstream (in-tree omarchy.elsewhen) =="
# Upstream moved Elsewhen in-tree as omarchy.elsewhen and drops the separate
# package (upstream/migrations/1790528634.sh). The Fedora elsewhen RPM installed
# the old out-of-tree plugin and duplicated the world clock on fresh installs.
# Guard the retirement: retired-packages.conf prunes it, packages.yaml marks it,
# the old placing migration is gone, and the retire migration renames/dedups.
t "elsewhen retired in retired-packages.conf" python3 -c "
names = [l.split('#')[0].strip() for l in open('fedora/mappings/retired-packages.conf')]
assert 'elsewhen' in names, 'elsewhen must be retired'
"
t "elsewhen marked RETIRED in packages.yaml" python3 -c "
import yaml
n = yaml.safe_load(open('fedora/mappings/packages.yaml'))['packages']['elsewhen'].get('note','')
assert 'RETIRED' in n, 'elsewhen note must mark RETIRED'
"
t "old elsewhen placing migration removed" bash -c "! ls fedora/migrations/*-elsewhen-plugin.sh >/dev/null 2>&1"
t "elsewhen retire migration renames and dedups" python3 -c "
import glob
migs = glob.glob('fedora/migrations/*-elsewhen-retire.sh')
assert len(migs) == 1, migs
mig = open(migs[0]).read()
assert 'omacom.elsewhen' in mig and 'omarchy.elsewhen' in mig, 'must rename old id to new'
assert 'dedup' in mig, 'must deduplicate double entries'
assert 'rpm -q elsewhen' in mig, 'must drop the retired RPM'
assert 'omacom-elsewhen' in mig, 'must clean the old cache dir'
assert '.config/omarchy/plugins/omacom.elsewhen' in mig, 'must clean the dev-checkout symlink'
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

echo "== Installer takes over the display manager (GDM / PLM bases) =="
# On Fedora Workstation GDM owns display-manager.service, and on Fedora 44+
# KDE Plasma Login Manager (plasmalogin.service) owns it, so `systemctl enable
# sddm` fails and the Omarchy greeter never appears. install.sh must disable the
# other DMs first and force-enable SDDM.
t "install.sh disables competing DMs before enabling SDDM" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert '_enable_display_manager()' in src, 'missing _enable_display_manager helper'
assert 'gdm.service' in src and '_systemctl_disable' in src, 'must disable GDM'
assert 'plasmalogin.service' in src, 'must disable Plasma Login Manager (F44+ KDE default)'
assert 'enable --force' in src, 'DM enable must use --force to replace the alias'
assert src.count('_enable_display_manager') >= 2, '_enable_display_manager must be defined and called'
assert 'display-manager.service' in src, 'must account for the display-manager alias'
"

echo "== Opt-in omarchy-plus session chooser (converted machines) =="
# Stock upstream greeter has no session/user picker; converted Fedora machines
# lose their KDE/Sway choice. The opt-in plus theme installs alongside stock
# (never modifies it), symlinks artwork so recolors track, and selects itself
# with a zz- drop-in that sorts after 10-theme/99-omarchy-login. Default stays
# pure stock; update mode re-asserts the last-installed state via marker.
t "chooser flag parsing" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert '--with-session-chooser' in src, 'missing opt-in flag'
assert '--without-session-chooser' in src, 'missing revert flag'
assert 'SESSION_CHOOSER_EXPLICIT' in src, 'must track explicit flag for update mode'
"
t "chooser installs alongside stock, never overwrites" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'install_omarchy_sddm_chooser()' in src, 'missing chooser helper'
assert src.count('install_omarchy_sddm_chooser') >= 2, 'chooser must be defined and called'
assert 'themes/omarchy-plus' in src, 'must install as separate omarchy-plus theme'
assert 'zz-omarchy-plus.conf' in src, 'must select via zz- drop-in (sorts last)'
assert 'Current=omarchy-plus' in src, 'drop-in must set Current=omarchy-plus'
assert 'ln -sfn' in src, 'artwork must be symlinked, not copied'
assert '/var/lib/omarchy-fedora/session-chooser' in src, 'update mode must re-assert via marker'
"
t "chooser QML has session + username choice, SDDM 0.21-safe" python3 -c "
qml = open('fedora/sddm-omarchy-plus/Main.qml').read()
assert 'sessionPicker' in qml and 'username' in qml, 'must add a session picker + username field'
assert 'Qt.UserRole + 4' in qml, 'session lookup must use UserRole+4 (DisplayRole is broken on SDDM 0.21)'
assert 'sessionModel' in qml and 'model.name' in qml, 'session list must be driven by sessionModel'
assert 'sddm.login(username.text' in qml, 'login must use the chosen user + session'
assert 'import QtQuick.Controls' not in qml, 'must not require QtQuick.Controls (greeter may not load it)'
assert 'import QtQuick 2.0' in qml and 'import SddmComponents 2.0' in qml, 'must keep the stock imports'
assert 'sessionProbe' in qml, 'need the model probe so the label re-binds when SDDM populates it'
"
t "chooser revert path" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'rm -f' in src and 'zz-omarchy-plus.conf' in src, 'must remove drop-in when disabled'
u = open('fedora/scripts/uninstall.sh').read()
assert 'themes/omarchy-plus' in u and 'zz-omarchy-plus.conf' in u, 'uninstall must clean the plus theme'
"

echo "== Opt-in session chooser migration for existing installs =="
# install.sh --with-session-chooser only helps fresh installs; older ones opt in
# with fedora/scripts/enable-session-chooser.sh. It must publish the SAME
# canonical theme (never a hand-installed copy), select it, set the marker, and
# disable the leftover SDDM autologin -- which bypasses the greeter, so the
# chooser would be unreachable at boot. It must NOT be a fedora/migrations/
# entry, since those run automatically on every update and opting in is a
# user decision.
t "enable-session-chooser.sh syntax" bash -n fedora/scripts/enable-session-chooser.sh
t "chooser migration: canonical theme + marker + disable autologin" python3 -c "
src = open('fedora/scripts/enable-session-chooser.sh').read()
assert 'fedora/sddm-omarchy-plus' in src, 'must install from the owned theme source'
assert 'themes/omarchy-plus' in src, 'must target themes/omarchy-plus'
assert 'zz-omarchy-plus.conf' in src, 'must select via the zz- drop-in'
assert '/var/lib/omarchy-fedora/session-chooser' in src, 'must set the marker update mode reads'
assert 'autologin.conf' in src and '/etc/sddm.conf' in src, 'must disable leftover autologin'
assert 'ln -sfn' in src, 'artwork must be symlinked, not copied'
"
t "chooser migration is opt-in (not an automatic migration)" bash -c "! ls fedora/migrations/*session-chooser*.sh >/dev/null 2>&1"
t "chooser migration documented in the theme README" python3 -c "
src = open('fedora/sddm-omarchy-plus/README.md').read()
assert 'enable-session-chooser.sh' in src, 'README must document the migration'
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

echo "== Update upgrades mise-managed tools (matches upstream) =="
# Upstream's omarchy-update-mise runs on every `omarchy update`, overriding
# mise's release-age cooldown (MISE_MINIMUM_RELEASE_AGE=0) so tools advance.
# The Fedora updater must do the same, as the target user (mise toolchains are
# per-$HOME), and best-effort so a failed tool build cannot block the update.
t "update.sh upgrades mise tools as the target user" python3 -c "
src = open('fedora/scripts/update.sh').read()
assert 'omarchy_fedora_update_mise' in src, 'missing mise update helper'
assert src.count('omarchy_fedora_update_mise') >= 2, 'helper must be defined and called'
assert 'MISE_MINIMUM_RELEASE_AGE=0' in src, 'must override mise release-age cooldown'
assert 'mise upgrade' in src, 'must run mise upgrade'
assert 'runuser -u' in src, 'must drop to the target user when run as root'
assert 'SUDO_USER' in src, 'must prefer SUDO_USER when choosing the target user'
"

echo "== Agents install via mise (matches upstream) =="
# Upstream installs its coding-agent CLIs (opencode, codex, claude, ...) through
# mise at user setup, not as RPMs. The Fedora layer must do the same: install.sh
# runs the helper on fresh installs, a migration converges existing installs,
# and the helper drives the vendored upstream install/user/mise.sh as the user.
t "install.sh wires the mise agent setup" python3 -c "
src = open('fedora/scripts/install.sh').read()
assert 'lib/mise.sh' in src, 'must source the mise lib'
assert 'omarchy_fedora_install_mise_tools' in src, 'must call the helper'
"
t "mise lib runs the vendored upstream mise.sh as the user" python3 -c "
src = open('fedora/scripts/lib/mise.sh').read()
assert 'install/user/mise.sh' in src, 'must run the upstream agent setup'
assert 'runuser -u' in src, 'must drop to the target user when run as root'
assert 'HOME=' in src, 'agent tools are per-user home'
"
t "mise-agents migration exists and calls the helper" python3 -c "
import glob
migs = glob.glob('fedora/migrations/*-mise-agents.sh')
assert len(migs) == 1, migs
src = open(migs[0]).read()
assert 'omarchy_fedora_install_mise_tools' in src, 'must call the helper'
"

echo "== Elsewhen retire migration covers all users as themselves =="
# The migration runs as root (via sudo) and previously trusted XDG_RUNTIME_DIR
# from the environment. When that was root's /run/user/0 (no session), the shell
# ping went to the wrong socket and the migration wrongly reported no running
# shell. It must derive the runtime dir from the target user's uid.
t "retire migration targets all human users" python3 -c "
src = open('fedora/migrations/1792015000-elsewhen-retire.sh').read()
assert 'SUDO_USER' in src, 'must prefer SUDO_USER'
assert '1000' in src, 'must cover uid>=1000 users'
assert 'runuser -u' in src, 'must edit user files as the user'
"

echo "== Bundled application icons reach the hicolor theme =="
# Upstream's omarchy-settings package installs applications/icons/* into
# /usr/share/icons/hicolor/{48x48,256x256,scalable}/apps under safe_icon_name()
# names, which is exactly what the shipped launchers' Icon= keys reference. The
# port copies the tree and the launchers, so missing the packaging step left
# every bundled web app (X, YouTube, Discord, ...) on the generic gear icon.
t "install.sh installs bundled app icons" python3 -c "
lib = open('fedora/scripts/lib/app-icons.sh').read()
assert 'omarchy_fedora_install_app_icons()' in lib, 'must define the icon step'
assert '256x256/apps' in lib and '48x48/apps' in lib, 'must use the hicolor sizes upstream uses'
assert 'mktemp -d' in lib, 'must stage, so a partial render never lands in the theme'
src = open('fedora/scripts/install.sh').read()
assert 'lib/app-icons.sh' in src, 'install.sh must source the lib'
assert '\n  omarchy_fedora_install_app_icons\n' in src, 'install.sh must call it from main'
"
t "bundled icons cover the launchers' Icon= keys" python3 -c "
import glob, os, re
def safe(name):
    name = re.sub(r'[^A-Za-z0-9]+', '-', name.lower()).strip('-')
    return name
icons = {safe(os.path.splitext(os.path.basename(p))[0])
         for p in glob.glob('upstream/applications/icons/*')}
# foot and mpv are real programs whose icons come from their own packages.
system = {'foot', 'mpv'}
wanted = set()
for d in glob.glob('upstream/applications/*.desktop'):
    m = re.search(r'^Icon=(.+)\$', open(d).read(), re.M)
    if m:
        wanted.add(m.group(1).strip())
missing = wanted - system - icons
assert not missing, 'launchers reference icons the tree never installs: %s' % sorted(missing)
"

echo
echo "== Result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] || exit 1
