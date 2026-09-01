#!/usr/bin/env bash
# Build SRPMs for the Omarchy first-party RPMs and submit them to the
# whelanh/omarchy COPR for remote building.
#
# Usage:
#   fedora/rpm/copr/submit-builds.sh                 # all verified packages
#   fedora/rpm/copr/submit-builds.sh aether ttfx     # only these packages
#   fedora/rpm/copr/submit-builds.sh --srpms-only    # build SRPMs, no submit
#
# Requires:
#   - copr-cli (dnf install -y copr-cli) + login (see README.md)
#   - rpm-build, python3 + pyyaml
#
# Each SRPM is produced with `rpmbuild -bs` from fedora/rpm/<pkg>/<pkg>.spec
# (sources are downloaded locally first). Then `copr-cli build` pushes the
# SRPM and COPR builds it in its chroot (fedora-rawhide-x86_64 with the
# nett00n/hyprland build repo, see create-project.sh).
set -euo pipefail

RPM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$RPM_DIR/manifest.yaml"
COPR="whelanh/omarchy"
SUBMIT=1
TOP="${HOME}/rpmbuild-omarchy"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
need rpmbuild
need python3

for a in "$@"; do
  [ "$a" = "--srpms-only" ] && SUBMIT=0
done

# Packages to build: explicit args minus flags, else manifest 'verified' set.
pkgs=()
for a in "$@"; do
  case "$a" in
    --srpms-only) ;;
    *) pkgs+=("$a") ;;
  esac
done
if [ "${#pkgs[@]}" -eq 0 ]; then
  while IFS= read -r p; do pkgs+=("$p"); done < <(
    python3 - "$MANIFEST" <<'PY'
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
print('\n'.join(sorted(p for p,v in d['packages'].items() if v['status']=='verified')))
PY
  )
fi
echo "packages: ${pkgs[*]}"

mkdir -p "$TOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
SRPMS=()
for pkg in "${pkgs[@]}"; do
  spec="$RPM_DIR/$pkg/$pkg.spec"
  [ -f "$spec" ] || { echo "no spec for $pkg; skipping" >&2; continue; }
  echo "== building SRPM: $pkg =="
  rm -rf "$TOP/SOURCES"/*; mkdir -p "$TOP/SOURCES"
  cp "$spec" "$TOP/SPECS/$pkg.spec"
  # Download spec sources (same expansion logic as build-rpm-in-ci.sh).
  (cd "$TOP/SOURCES" && python3 - "$spec" <<'PY'
import re,sys,urllib.request,os
spec=open(sys.argv[1]).read()
def f(k):
    m=re.search(r'^%s:\s*(\S+)'%k,spec,re.M); return m.group(1) if m else ''
url,ver,name=f('URL'),f('Version'),f('Name')
macros={}
for m in re.finditer(r'^%global\s+(\S+)\s+(\S+)',spec,re.M):
    macros[m.group(1)]=m.group(2)
def expand(u):
    for k,v in list(macros.items())+[('url',url),('version',ver),('name',name)]:
        u=u.replace('%%{%s}'%k,v)
    return u
for m in re.finditer(r'^Source\d*:\s*(\S+)',spec,re.M):
    u=expand(m.group(1))
    fn=os.path.basename(u)
    if not os.path.exists(fn):
        print('fetching',u); urllib.request.urlretrieve(u,fn)
PY
)
  rpmbuild --define "_topdir $TOP" -bs "$spec" || { echo "SRPM build failed: $pkg" >&2; exit 1; }
  SRPMS+=("$TOP/SRPMS/${pkg}"*)
done

[ -n "${SRPMS[*]}" ] || { echo "no SRPMs produced" >&2; exit 1; }
echo
echo "SRPMs:"
printf '   %s\n' "${SRPMS[@]}"

if [ "$SUBMIT" = 1 ]; then
  need copr-cli
  echo "== submitting ${#SRPMS[@]} SRPM(s) to $COPR =="
  copr-cli build --nowait "$COPR" "${SRPMS[@]}"
  echo
  echo "Submitted. Watch progress: copr-cli list-watch --output-format text"
else
  echo "(--srpms-only: not submitting; SRPMs left in $TOP/SRPMS)"
fi