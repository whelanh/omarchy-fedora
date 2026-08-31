#!/usr/bin/env bash
# Build every 'verified' first-party SPEC directly in the current Fedora
# container (no podman/mock needed). This is what the CI `rpm-build` job runs.
# It is equivalent to `build-in-container.sh` but assumes it is already running
# *inside* a Fedora container.
set -euo pipefail

RPM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

build_one() {
  local pkg="$1" spec="$2"
  echo "== building $pkg =="
  local topdir="/tmp/rpmbuild-$pkg"
  rm -rf "$topdir"
  mkdir -p "$topdir"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

  local name version url gem_name
  name="$(python3 - "$spec" <<'PY'
import re,sys
print(re.search(r'^Name:\s*(\S+)', open(sys.argv[1]).read(), re.M).group(1))
PY
)"
  version="$(python3 - "$spec" <<'PY'
import re,sys
print(re.search(r'^Version:\s*(\S+)', open(sys.argv[1]).read(), re.M).group(1))
PY
)"

  cp "$spec" "$topdir/SPECS/$pkg.spec"

  # Fetch Source URLs into SOURCES (best effort; expands common macros).
  (
    cd "$topdir/SOURCES"
    python3 - "$spec" <<'PY'
import re,sys,urllib.request,os
spec=open(sys.argv[1]).read()
def f(k):
    m=re.search(r'^%s:\s*(\S+)'%k,spec,re.M); return m.group(1) if m else ''
url,ver,name=f('URL'),f('Version'),f('Name')
gm=re.search(r'^%global\s+gem_name\s+(\S+)',spec,re.M); gm=gm.group(1) if gm else ''
for m in re.finditer(r'^Source\d*:\s*(\S+)',spec,re.M):
    u=m.group(1)
    for a,b in (('%{url}',url),('%{version}',ver),('%{name}',name),('%{gem_name}',gm)):
        u=u.replace(a,b)
    fn=os.path.basename(u)
    if not os.path.exists(fn):
        print('fetching',u); urllib.request.urlretrieve(u,fn)
PY
  )

  dnf -y builddep "$topdir/SPECS/$pkg.spec" >/dev/null 2>&1 || true
  rpmbuild --define "_topdir $topdir" -ba "$topdir/SPECS/$pkg.spec"
  echo "OK: $pkg built"
}

main() {
  local manifest="$RPM_DIR/manifest.yaml"
  local -a verified=()
  while IFS= read -r pkg; do
    verified+=("$pkg")
  done < <(python3 - "$manifest" <<'PY'
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
print('\n'.join(sorted(p for p,v in d['packages'].items() if v['status']=='verified')))
PY
)
  if [ "${#verified[@]}" -eq 0 ]; then
    echo "no verified packages to build"; exit 0
  fi
  echo "verified packages: ${verified[*]}"
  for pkg in "${verified[@]}"; do
    build_one "$pkg" "$RPM_DIR/$pkg/$pkg.spec"
  done
  echo "All verified first-party RPMs built successfully."
}

main "$@"
