#!/usr/bin/env bash
# Build a single 'verified' Omarchy SPEC inside a disposable Fedora Rawhide
# container (no mock, no KVM needed). Used by CI to validate the RPMs.
#
# Usage: fedora/rpm/build-in-container.sh <pkg>
#
# Exits 0 and prints the built RPM filename on success; non-zero on failure.
set -euo pipefail

RPM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKG="${1:-}"
[ -n "$PKG" ] || { echo "usage: $0 <pkg>" >&2; exit 2; }

SPEC="$RPM_DIR/$PKG/$PKG.spec"
[ -f "$SPEC" ] || { echo "no spec: $SPEC" >&2; exit 2; }

status="$(python3 - "$RPM_DIR/manifest.yaml" "$PKG" <<'PY'
import yaml,sys
print(yaml.safe_load(open(sys.argv[1]))["packages"][sys.argv[2]]["status"])
PY
)"
[ "$status" = "verified" ] || { echo "skipping $PKG (status=$status)"; exit 0; }

WORK="/tmp/rpmbuild-$PKG"
rm -rf "$WORK"; mkdir -p "$WORK"
cp "$SPEC" "$WORK/spec.spec"

cat > "$WORK/entry.sh" <<'ENTRY'
#!/usr/bin/env bash
set -euo pipefail
dnf -y install rpm-build dnf-plugins-core >/dev/null 2>&1
mkdir -p /root/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cp /work/spec.spec /root/rpmbuild/SPECS/
dnf -y builddep /root/rpmbuild/SPECS/*.spec >/dev/null 2>&1
cd /root/rpmbuild/SOURCES
python3 - /root/rpmbuild/SPECS/*.spec <<'PY'
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
rpmbuild -ba /root/rpmbuild/SPECS/*.spec
ENTRY
chmod +x "$WORK/entry.sh"

set +e
podman run --rm -v "$WORK":/work:Z fedora:rawhide bash /work/entry.sh 2>&1 | tee "$WORK/build.log"
rc=$?
set -e
if [ $rc -ne 0 ]; then
  echo "BUILD FAILED ($PKG)"
  exit 1
fi
echo "BUILD OK: $PKG"
