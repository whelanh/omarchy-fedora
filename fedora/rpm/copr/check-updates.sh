#!/usr/bin/env bash
# Check the Omarchy Fedora port for upstream drift.
#
# Default (no args): check the first-party COPR packages for newer upstream
# releases. Reads fedora/rpm/manifest.yaml (repo + packaged version) and, for
# each package, queries the upstream GitHub repo's release/tags and reports
# which packages have a newer version than the one currently packaged.
#
# --packages: diff upstream's package lists (upstream/install/omarchy-base +
# omarchy-other.packages) against our mapping (fedora/mappings/packages.yaml)
# and report:
#   - unmapped  upstream packages we haven't mapped yet (need action)
#   - stale     mappings for packages upstream no longer lists
#
# Usage:
#   bash fedora/rpm/copr/check-updates.sh
#   bash fedora/rpm/copr/check-updates.sh --packages
#
# Exit status is 0 when everything is current, 1 when something needs attention.
set -euo pipefail

RPM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$RPM_DIR/manifest.yaml"
REPO_ROOT="$(cd -- "$RPM_DIR/../.." && pwd)"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }

if [ "${1:-}" = "--packages" ]; then
  python3 - "$REPO_ROOT" <<'PY'
import sys, yaml

root = sys.argv[1]

def load_pkg_list(path):
    out = set()
    try:
        for line in open(path):
            line = line.split("#")[0].strip()
            if line:
                out.add(line)
    except FileNotFoundError:
        pass
    return out

upstream = load_pkg_list(f"{root}/upstream/install/omarchy-base.packages") \
         | load_pkg_list(f"{root}/upstream/install/omarchy-other.packages")

pkgs = yaml.safe_load(open(f"{root}/fedora/mappings/packages.yaml"))["packages"]
mapped = set(pkgs)

# A package upstream ships that we have no mapping for yet.
unmapped = sorted(upstream - mapped)
# A mapping whose package upstream no longer lists. `source: official` marks a
# Fedora-specific addition (a Fedora package name with no Arch upstream
# counterpart), so those are not "stale" — they are intentionally ours.
stale = sorted(k for k in mapped - upstream if pkgs[k].get("source") != "official")

if unmapped:
    print("Unmapped upstream packages (add a packages.yaml entry + a source):")
    for p in unmapped:
        print(f"  {p}")
    print()

if stale:
    print("Stale mappings (upstream no longer ships these; consider removing + a migration to uninstall):")
    for k in stale:
        print(f"  {k}  ->  {pkgs[k].get('source')} {pkgs[k].get('package', '')}")
    print()

if not unmapped and not stale:
    print("No package drift: every upstream package is mapped, nothing stale.")
    sys.exit(0)

print(f"{len(unmapped)} unmapped, {len(stale)} stale")
sys.exit(1)
PY
  exit
fi

python3 - "$MANIFEST" <<'PY'
import json, re, sys, urllib.request, yaml

UA = {"User-Agent": "omarchy-fedora-check", "Accept": "application/vnd.github+json"}

def gh_get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)

def semver(v):
    v = str(v).lstrip("vV").strip().split("-")[0].split("+")[0]
    nums = []
    for part in v.split("."):
        m = re.match(r"\d+", part)
        nums.append(int(m.group()) if m else 0)
    while len(nums) < 3:
        nums.append(0)
    return tuple(nums[:3])

_PRERE = re.compile(r"(^|[.\-])(alpha|beta|rc|pre|dev|nightly|snapshot)([.\-]|\d|$)", re.I)

def is_prerelease(v):
    return bool(_PRERE.search(str(v)))

def latest_github(owner, repo):
    cand = set()
    for path in ("/releases/latest", "/tags?per_page=50"):
        try:
            data = gh_get(f"https://api.github.com/repos/{owner}/{repo}{path}")
            if isinstance(data, dict):
                if data.get("tag_name"):
                    cand.add(data["tag_name"])
            elif isinstance(data, list):
                for t in data:
                    if t.get("name"):
                        cand.add(t["name"])
        except Exception:
            pass
    stable = [c for c in cand if not is_prerelease(c)]
    pool = stable or list(cand)
    return max(pool, key=semver) if pool else None

d = yaml.safe_load(open(sys.argv[1]))
rows = []
for name, p in sorted(d["packages"].items()):
    repo = p.get("repo", "")
    ver = str(p.get("version", ""))
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)", repo)
    latest = latest_github(m.group(1), m.group(2)) if m else None
    rows.append((name, ver, latest))

print(f"{'package':35} {'packaged':>10} {'latest':>10}  status")
print("-" * 72)
stale = 0
for name, ver, latest in rows:
    if latest is None:
        print(f"{name:35} {ver:>10} {'?':>10}  (unknown)")
        continue
    behind = semver(latest) > semver(ver)
    if behind:
        stale += 1
        print(f"{name:35} {ver:>10} {latest:>10}  OUTDATED")
    else:
        print(f"{name:35} {ver:>10} {latest:>10}  ok")
print()
if stale:
    print(f"{stale} package(s) out of date — bump Version: + %changelog, then:")
    print("  bash fedora/rpm/copr/submit-builds.sh <pkg>")
else:
    print("all packages current")
sys.exit(1 if stale else 0)
PY
