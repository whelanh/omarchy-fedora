#!/usr/bin/env bash
# Build every 'verified' first-party SPEC directly in the current Fedora
# container (no podman/mock needed). This is what the CI `rpm-build` job runs.
# It is equivalent to `build-in-container.sh` but assumes it is already running
# *inside* a Fedora container.
set -euo pipefail

RPM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Resolve a SPEC's BuildRequires, retrying a few times.
#
# dnf occasionally downloads one package from a mirror that is merely slow:
# run 40267322786 lost the owe leg to a codecs.fedoraproject.org/openh264 fetch
# that crawled below 1 KB/s and timed out, which is a transient network fault,
# not a dependency problem. Each retry reuses every package already cached, so
# it only re-fetches what failed, and the failure is still reported with dnf's
# own reason (never swallowed) when all attempts are exhausted.
dnf_builddep_retry() {
  local spec="$1" attempt
  for attempt in 1 2 3; do
    if dnf -y --setopt=retries=5 --setopt=timeout=60 builddep "$spec"; then
      return 0
    fi
    if (( attempt == 3 )); then
      break
    fi
    echo "omarchy: dnf builddep attempt $attempt/3 failed for" \
      "$(basename "$spec"); retrying in $((attempt * 15))s" >&2
    sleep $((attempt * 15))
  done
  echo "omarchy: dnf builddep could not resolve BuildRequires for" \
    "$(basename "$spec") after 3 attempts (see dnf's reason above)" >&2
  return 1
}

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
# Some vendors block the default Python-urllib User-Agent; use a browser one.
_opener = urllib.request.build_opener()
_opener.addheaders = [('User-Agent', 'Mozilla/5.0')]
urllib.request.install_opener(_opener)
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

  dnf_builddep_retry "$topdir/SPECS/$pkg.spec" || return 1
  # Rust packages build offline from a vendored crates.io tarball; generate it
  # here (network + cargo are available in this container after builddep).
  . "$RPM_DIR/vendor-rust.sh"
  generate_rust_vendor "$spec" "$topdir/SOURCES" "/tmp/vendor-$pkg"
  rpmbuild --define "_topdir $topdir" -ba "$topdir/SPECS/$pkg.spec"
  echo "OK: $pkg built"
}

main() {
  local manifest="$RPM_DIR/manifest.yaml"
  local -a verified=()

  if [ -n "${1:-}" ]; then
    # explicit package list (used with FORCE=1 to verify not-yet-verified specs)
    verified=("$@")
  else
    while IFS= read -r pkg; do
      verified+=("$pkg")
    done < <(python3 - "$manifest" <<'PY'
import yaml,sys
d=yaml.safe_load(open(sys.argv[1]))
print('\n'.join(sorted(p for p,v in d['packages'].items() if v['status']=='verified')))
PY
)
  fi
  if [ "${#verified[@]}" -eq 0 ]; then
    echo "no packages to build"; exit 0
  fi
  echo "packages: ${verified[*]}"
  for pkg in "${verified[@]}"; do
    [ -f "$RPM_DIR/$pkg/$pkg.spec" ] || { echo "no spec for $pkg; skipping"; continue; }
    build_one "$pkg" "$RPM_DIR/$pkg/$pkg.spec"
  done
  echo "All requested first-party RPMs built successfully."
}

main "$@"
