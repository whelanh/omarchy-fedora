#!/usr/bin/env bash
# Build SRPMs for the Omarchy first-party RPMs and submit them to the
# whelanh/omarchy COPR for remote building.
#
# Usage:
#   fedora/rpm/copr/submit-builds.sh                 # all verified packages, all chroots
#   fedora/rpm/copr/submit-builds.sh aether ttfx     # only these packages
#   fedora/rpm/copr/submit-builds.sh --srpms-only    # build SRPMs, no submit
#   fedora/rpm/copr/submit-builds.sh --chroot fedora-45-x86_64   # only this chroot
#
# Requires:
#   - copr-cli (dnf install -y copr-cli) + login (see README.md)
#   - rpm-build, python3 + pyyaml
#
# Each SRPM is produced with `rpmbuild -bs` from fedora/rpm/<pkg>/<pkg>.spec
# (sources are downloaded locally first). Then `copr-cli build` pushes the
# SRPM and COPR builds it in every enabled chroot of the project — or, when
# one or more --chroot flags are given, only those chroots (see
# create-project.sh for how the nett00n/hyprland build repo is wired per
# chroot).
set -euo pipefail

RPM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$RPM_DIR/manifest.yaml"
COPR="whelanh/omarchy"
SUBMIT=1
TOP="${HOME}/rpmbuild-omarchy"
CHROOTS=()

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
need rpmbuild
need python3

# resolve the RPM Name from a spec (mirrors install-rpms.sh)
spec_name() {
  python3 - "$1" <<'PY'
import re,sys
print(re.search(r'^Name:\s*(\S+)', open(sys.argv[1]).read(), re.M).group(1))
PY
}

# Packages to build: explicit args minus flags, else manifest 'verified' set.
# Flags: --srpms-only (don't submit), --chroot <name> (repeatable; submit to
# only these chroots instead of every enabled project chroot).
pkgs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --srpms-only) SUBMIT=0 ;;
    --chroot) CHROOTS+=("$2"); shift ;;
    *) pkgs+=("$1") ;;
  esac
  shift
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
# clear stale SRPMs from a prior run so the per-package glob below only matches
# the SRPM just built (avoids resubmitting old versions).
rm -rf "$TOP/SRPMS"/*
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
    if not u.startswith(('http://','https://')):
        continue
    fn=os.path.basename(u)
    if not os.path.exists(fn):
        print('fetching',u); urllib.request.urlretrieve(u,fn)
PY
)
  # Rust packages build offline in COPR from a vendored crates.io tarball.
  . "$RPM_DIR/vendor-rust.sh"
  generate_rust_vendor "$spec" "$TOP/SOURCES" "/tmp/omarchy-vendor-$pkg"
  rpm_name="$(spec_name "$spec")"
  rpmbuild --define "_topdir $TOP" -bs "$spec" || { echo "SRPM build failed: $pkg" >&2; exit 1; }
  SRPMS+=("$TOP/SRPMS/${rpm_name}"*)
done

[ -n "${SRPMS[*]}" ] || { echo "no SRPMs produced" >&2; exit 1; }
echo
echo "SRPMs:"
printf '   %s\n' "${SRPMS[@]}"

if [ "$SUBMIT" = 1 ]; then
  need copr-cli
  chroot_args=()
  for c in "${CHROOTS[@]}"; do chroot_args+=(-r "$c"); done
  if [ "${#CHROOTS[@]}" -gt 0 ]; then
    echo "== submitting ${#SRPMS[@]} SRPM(s) to $COPR (chroots: ${CHROOTS[*]}) =="
  else
    echo "== submitting ${#SRPMS[@]} SRPM(s) to $COPR (all chroots) =="
  fi
  copr-cli build --nowait "$COPR" "${chroot_args[@]}" "${SRPMS[@]}"
  echo
  echo "Submitted. Watch progress: copr-cli list-builds $COPR"
else
  echo "(--srpms-only: not submitting; SRPMs left in $TOP/SRPMS)"
fi