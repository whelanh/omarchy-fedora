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
# Rows triaged as accepted are listed in
# fedora/mappings/package-audit-baseline.conf and suppressed, so the report
# shows only new drift; resolved baseline entries are flagged for cleanup.
# Retired packages and `official`/`drop`/`unavailable` mappings are filtered
# out (they are deliberate, not drift).
#
# --pins: report specs that pin auxiliary files to a specific
# omacom/omarchy-pkgs commit (Source URLs like
# raw.githubusercontent.com/omacom/omarchy-pkgs/<sha>/pkgbuilds/<pkg>/<file>)
# whose file has since changed on omarchy-pkgs master. The app version is
# tracked separately; these helper files (launcher, service, desktop entries,
# release keys, setup scripts) can change independently, so the pin needs
# updating when they do.
#
# --rebuilds: report verified packages whose `rebuild_on` COPR dependency has a
# newer successful build than the package itself. A native Hyprland plugin is
# compiled against the compositor's private headers, and Hyprland's plugin ABI
# hash covers its dependency versions too, so a dependency-only rebuild (for
# example hyprland 0.57.0-4 -> 0.57.0-5 moving to aquamarine 0.16) invalidates
# the plugin even when the plugin's own version has not changed. The check is
# deliberately conservative: it compares COPR build completion times, so a
# rebuild is cheap insurance rather than a proof of ABI drift. `--porcelain`
# prints one `package<TAB>trigger` line per stale package.
#
# Usage:
#   bash fedora/rpm/copr/check-updates.sh
#   bash fedora/rpm/copr/check-updates.sh --packages
#   bash fedora/rpm/copr/check-updates.sh --pins
#   bash fedora/rpm/copr/check-updates.sh --rebuilds [--porcelain]
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
retired = load_pkg_list(f"{root}/fedora/mappings/retired-packages.conf")
baseline = load_pkg_list(f"{root}/fedora/mappings/package-audit-baseline.conf")

# A package upstream ships that we have no mapping for yet.
unmapped_all = sorted(upstream - mapped)
# A mapping whose package upstream no longer lists. `source: official` marks a
# Fedora-specific addition, `drop`/`unavailable` are deliberate classifications,
# so none of those are drift. Retired packages keep their mapping for reference
# but are excluded too (retired-packages.conf already drives their removal).
stale_all = sorted(
    k for k in mapped - upstream
    if pkgs[k].get("source") not in ("official", "drop", "unavailable")
    and k not in retired
    and str(pkgs[k].get("package") or "") not in retired
)

# Rows triaged once and accepted in package-audit-baseline.conf are suppressed,
# so the report only surfaces new drift. Delete a baseline line when fixed.
unmapped = [p for p in unmapped_all if p not in baseline]
stale = [k for k in stale_all if k not in baseline]
suppressed = (len(unmapped_all) - len(unmapped)) + (len(stale_all) - len(stale))

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

if suppressed:
    print(f"({suppressed} known row(s) suppressed by fedora/mappings/package-audit-baseline.conf)")

# Hygiene: a baseline entry that no longer describes a row is resolved.
live = set(unmapped_all) | set(stale_all)
resolved = sorted(baseline - live)
if resolved:
    print()
    print("Baseline entries no longer needed (delete from package-audit-baseline.conf):")
    for p in resolved:
        print(f"  {p}")

if not unmapped and not stale:
    print("No new package drift: every upstream package is mapped or baselined, nothing newly stale.")
    sys.exit(0)

print(f"{len(unmapped)} unmapped, {len(stale)} stale")
sys.exit(1)
PY
  exit
fi

if [ "${1:-}" = "--rebuilds" ]; then
  PORCELAIN=0
  [ "${2:-}" = "--porcelain" ] && PORCELAIN=1
  python3 - "$MANIFEST" "$PORCELAIN" <<'PY'
import datetime, json, sys, urllib.parse, urllib.request, yaml

manifest, porcelain = sys.argv[1], sys.argv[2] == "1"
COPR_OWNER, COPR_PROJECT = "whelanh", "omarchy"
UA = {"User-Agent": "omarchy-fedora-check"}

def api(path):
    req = urllib.request.Request(f"https://copr.fedorainfracloud.org/api_3/{path}", headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def latest_success(owner, project, package):
    qs = urllib.parse.urlencode({
        "ownername": owner, "projectname": project, "packagename": package,
        "limit": 20,
    })
    items = api(f"build/list/?{qs}").get("items") or []
    good = [b for b in items if b.get("state") == "succeeded"]
    return max(good, key=lambda b: b.get("ended_on") or b.get("submitted_on") or 0) if good else None

def when(build):
    ts = (build or {}).get("ended_on") or (build or {}).get("submitted_on")
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime("%Y-%m-%d") if ts else "?"

def version(build):
    return ((build or {}).get("source_package") or {}).get("version") or "?"

pkgs = yaml.safe_load(open(manifest))["packages"]
dependent = {n: p for n, p in pkgs.items()
             if p.get("status") == "verified" and p.get("rebuild_on")}

if not dependent:
    print("No packages declare rebuild_on; nothing to check.")
    sys.exit(0)

rows, stale = [], []
for name, p in sorted(dependent.items()):
    own = latest_success(COPR_OWNER, COPR_PROJECT, name)
    triggers = p["rebuild_on"] if isinstance(p["rebuild_on"], list) else [p["rebuild_on"]]
    newest, newest_name = None, ""
    for trig in triggers:
        if isinstance(trig, str):
            owner, project, package = "nett00n", "hyprland", trig
        else:
            owner, project = trig["copr"].split("/", 1)
            package = trig["package"]
        b = latest_success(owner, project, package)
        if b and (newest is None or (b.get("ended_on") or 0) > (newest.get("ended_on") or 0)):
            newest, newest_name = b, f"{package} {version(b)}"
    if not newest:
        rows.append((name, "unknown", f"{version(own)} ({when(own)})", "UNKNOWN"))
        continue

    # A build that finished after the trigger's build did may still have
    # resolved the older headers, but the window is tiny; flag conservatively.
    if own is None:
        status = "MISSING"
        stale.append(name)
    elif (newest.get("ended_on") or 0) > (own.get("ended_on") or 0):
        status = "REBUILD"
        stale.append(name)
    else:
        status = "ok"
    rows.append((name, f"{newest_name} ({when(newest)})", f"{version(own)} ({when(own)})", status))

if porcelain:
    trig_by_name = {name: trig for name, trig, own, status in rows}
    print("\n".join(f"{name}\t{trig_by_name[name]}" for name in stale))
else:
    print(f"{'package':32} {'trigger build':32} {'package build':24}  status")
    print("-" * 100)
    for name, trig, own, status in rows:
        print(f"{name:32} {trig:32} {own:24}  {status}")
    print()
    if stale:
        print(f"{len(stale)} package(s) need a rebuild: bump Release: (Version: stays put),")
        print("add a %changelog entry, then submit:")
        print("  bash fedora/rpm/copr/submit-builds.sh " + " ".join(stale))
    else:
        print("all rebuild_on dependents are newer than their trigger builds")

sys.exit(1 if stale else 0)
PY
  exit
fi

if [ "${1:-}" = "--pins" ]; then
  python3 - "$RPM_DIR" <<'PY'
import glob, os, re, sys, urllib.request

rpm_dir = sys.argv[1]
# Source URLs that pin a file inside omacom/omarchy-pkgs at a commit SHA.
PIN_RE = re.compile(
    r"raw\.githubusercontent\.com/omacom/omarchy-pkgs/([0-9a-f]{7,40})/pkgbuilds/([^/]+)/([^/\s#]+)")

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "omarchy-fedora-check"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()

entries, seen = [], set()
for spec in sorted(glob.glob(os.path.join(rpm_dir, "*", "*.spec"))):
    name = os.path.basename(os.path.dirname(spec))
    for m in PIN_RE.finditer(open(spec).read()):
        sha, pkg, fname = m.groups()
        if (pkg, fname, sha) in seen:
            continue
        seen.add((pkg, fname, sha))
        entries.append((name, pkg, fname, sha))

if not entries:
    print("No omarchy-pkgs commit pins found.")
    sys.exit(0)

print(f"{'package':22} {'file':28} {'pinned':>12}  status")
print("-" * 80)
stale = 0
for name, pkg, fname, sha in entries:
    pinned = current = None
    try:
        pinned = fetch(f"https://raw.githubusercontent.com/omacom/omarchy-pkgs/{sha}/pkgbuilds/{pkg}/{fname}")
    except Exception:
        pass
    try:
        current = fetch(f"https://raw.githubusercontent.com/omacom/omarchy-pkgs/master/pkgbuilds/{pkg}/{fname}")
    except Exception:
        pass
    if pinned is None:
        status = "pinned unreadable"
    elif current is None:
        status = "REMOVED upstream"
        stale += 1
    elif pinned != current:
        status = "OUTDATED"
        stale += 1
    else:
        status = "ok"
    print(f"{name:22} {fname:28} {sha[:12]:>12}  {status}")

print()
if stale:
    print(f"{stale} pinned file(s) differ from omarchy-pkgs master — review them,")
    print("update the commit SHA in the spec (bump Release: + a %changelog entry),")
    print("then resubmit: bash fedora/rpm/copr/submit-builds.sh <pkg>")
else:
    print("all omarchy-pkgs pins current")
sys.exit(1 if stale else 0)
PY
  exit
fi

python3 - "$MANIFEST" <<'PY'
import json, os, re, sys, urllib.request, yaml

UA = {"User-Agent": "omarchy-fedora-check", "Accept": "application/vnd.github+json"}
# Same token support as auto-update.sh: without it this report is capped at 60
# unauthenticated requests/hour (~2 per upstream repo) and mostly prints
# "(unknown)" for every package.
_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
if _token:
    UA["Authorization"] = f"Bearer {_token}"

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
    # Must agree with auto-update.sh, which is the thing that acts on this
    # report: prefer the maintainer's "latest release" (GitHub omits
    # prereleases from it), and only fall back to tags when there is none.
    # Unioning /releases with /tags made a prerelease tagged `v0.3.0` (no "rc"
    # in the name) win the semver comparison and show up as OUTDATED even
    # though the updater -- correctly -- never bumps to it.
    try:
        data = gh_get(f"https://api.github.com/repos/{owner}/{repo}/releases/latest")
        if isinstance(data, dict) and data.get("tag_name"):
            return data["tag_name"]
    except Exception:
        pass
    cand = set()
    try:
        data = gh_get(f"https://api.github.com/repos/{owner}/{repo}/tags?per_page=50")
        if isinstance(data, list):
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
    # Retired packages are no longer built/published/submitted; don't nudge the
    # maintainer to bump them.
    if p.get("status") == "retired":
        continue
    repo = p.get("repo", "")
    ver = str(p.get("version", ""))
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)", repo)
    latest = latest_github(m.group(1), m.group(2)) if m else None
    rows.append((name, ver, latest, str(p.get("hold") or "").strip()))

print(f"{'package':35} {'packaged':>10} {'latest':>10}  status")
print("-" * 72)
stale = 0
held_ahead = 0
for name, ver, latest, hold in rows:
    if latest is None:
        print(f"{name:35} {ver:>10} {'?':>10}  (unknown)")
        continue
    behind = semver(latest) > semver(ver)
    if behind and hold:
        # Deliberately pinned: upstream is ahead but needs a dependency we can't
        # get yet (see the hold: reason in manifest.yaml). Not out of date.
        held_ahead += 1
        print(f"{name:35} {ver:>10} {latest:>10}  HELD ({hold})")
        continue
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
if held_ahead:
    print(f"{held_ahead} held package(s) behind upstream by design (see hold: in manifest.yaml)")
sys.exit(1 if stale else 0)
PY
