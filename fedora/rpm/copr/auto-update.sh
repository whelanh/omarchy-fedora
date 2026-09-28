#!/usr/bin/env bash
# Check the first-party Omarchy COPR packages for newer upstream releases, bump
# the spec Version/Release + %changelog and manifest.yaml version for the ones
# that are behind, then submit the changed packages to the whelanh/omarchy COPR.
#
# This automates the manual loop documented in README.md ("Rebuild / update
# policy"): detect drift, edit fedora/rpm/<pkg>/<pkg>.spec, sync
# fedora/rpm/manifest.yaml, then run submit-builds.sh.
#
# Usage:
#   fedora/rpm/copr/auto-update.sh                  # plan, confirm, bump, submit
#   fedora/rpm/copr/auto-update.sh --dry-run        # show the plan, change nothing
#   fedora/rpm/copr/auto-update.sh --yes            # no confirmation prompt
#   fedora/rpm/copr/auto-update.sh --srpms-only     # bump + build SRPMs, no submit
#   fedora/rpm/copr/auto-update.sh --verify         # container-verify before submit
#   fedora/rpm/copr/auto-update.sh --chroot fedora-44-x86_64
#
# Notes:
#   - Only packages with `status: verified` in manifest.yaml are considered;
#     the others are not part of the COPR.
#   - Packages that share an upstream repo (owe + owe-lockfeed) are bumped
#     together to the same version.
#   - The current version is read from each spec, not the manifest, so a stale
#     manifest cannot hide a needed bump. Both are written on success.
#   - All file edits happen in memory and are only written once every edit has
#     succeeded, so a failure never leaves a half-bumped tree.
#   - The maintainer identity in new %changelog entries is taken from the
#     spec's existing entry (falling back to git config / OMARCHY_RPM_MAINTAINER).
#
# Requires: python3 + pyyaml, and for the submit step copr-cli + rpm-build
# (see README.md). Exit status is 0 on success/nothing-to-do, 1 on error.
set -euo pipefail

COP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RPM_DIR="$(cd -- "$COP_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$RPM_DIR/../.." && pwd)"
MANIFEST="$RPM_DIR/manifest.yaml"
SUBMIT="$COP_DIR/submit-builds.sh"
CONTAINER_BUILD="$RPM_DIR/build-rpm-in-ci.sh"
COPR="whelanh/omarchy"

usage() {
  cat <<'EOF'
Check first-party Omarchy COPR packages for newer upstream releases, bump the
specs + manifest.yaml, then submit the changed packages to whelanh/omarchy.

Usage:
  auto-update.sh                  plan, confirm, bump, submit
  auto-update.sh --dry-run        show the plan, change nothing
  auto-update.sh --yes            no confirmation prompt
  auto-update.sh --srpms-only     bump + build SRPMs, do not submit
  auto-update.sh --verify         container-verify before submitting
  auto-update.sh --chroot <name>  submit to only this chroot (repeatable)
EOF
}

DRY_RUN=0
ASSUME_YES=0
SUBMIT_BUILDS=1
VERIFY=0
CHROOTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --srpms-only|--no-submit) SUBMIT_BUILDS=0 ;;
    --verify)     VERIFY=1 ;;
    --chroot)     CHROOTS+=("${2:?--chroot needs a value}"); shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || {
  echo "python3-pyyaml required (sudo dnf install -y python3-pyyaml)" >&2; exit 2; }

# Resolve the maintainer once; per-spec changelog entries win inside apply.
MAINTAINER="${OMARCHY_RPM_MAINTAINER:-}"
if [ -z "$MAINTAINER" ]; then
  if command -v git >/dev/null 2>&1 \
     && [ -n "$(git -C "$REPO_ROOT" config user.name 2>/dev/null || true)" ] \
     && [ -n "$(git -C "$REPO_ROOT" config user.email 2>/dev/null || true)" ]; then
    MAINTAINER="$(git -C "$REPO_ROOT" config user.name) <$(git -C "$REPO_ROOT" config user.email)>"
  else
    MAINTAINER="whelanh <brickhousedevelopers@gmail.com>"
  fi
fi

PLAN="$(mktemp)"
CHANGED_OUT="$(mktemp)"
trap 'rm -f "$PLAN" "$CHANGED_OUT"' EXIT

if [ -n "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]; then
  echo "== checking upstream for verified packages in $COPR (authenticated) =="
else
  echo "== checking upstream for verified packages in $COPR =="
  echo "   (tip: export GITHUB_TOKEN/GH_TOKEN to avoid the 60 req/hour API limit)"
fi
python3 - "$RPM_DIR" "$MANIFEST" "$PLAN" <<'PY'
import json, os, re, sys, urllib.request, yaml

rpm_dir, manifest_path, plan_path = sys.argv[1], sys.argv[2], sys.argv[3]
UA = {"User-Agent": "omarchy-fedora-auto-update", "Accept": "application/vnd.github+json"}
# Optional token raises the unauthenticated GitHub API limit from 60 to 5000
# requests/hour (the script makes ~2 calls per upstream repo). Use a classic
# token with no scopes, or set GH_TOKEN; `gh auth token` also works.
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

def norm(tag):
    m = re.search(r"\d+(?:\.\d+)*", str(tag))
    return m.group(0) if m else None

def spec_version(name):
    path = os.path.join(rpm_dir, name, name + ".spec")
    try:
        src = open(path).read()
    except FileNotFoundError:
        return None
    m = re.search(r"(?m)^Version:\s*(\S+)", src)
    return m.group(1) if m else None

REPO_RE = re.compile(r"https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$")

d = yaml.safe_load(open(manifest_path))
pkgs = d["packages"]

# verified packages grouped by their upstream repo
by_repo = {}
for name, p in sorted(pkgs.items()):
    if p.get("status") != "verified":
        continue
    m = REPO_RE.match(p.get("repo", "") or "")
    if m:
        by_repo.setdefault(p["repo"], []).append(name)

plan, unknown, drift = [], [], []
for repo, names in sorted(by_repo.items()):
    owner, rname = REPO_RE.match(repo).groups()
    tag = latest_github(owner, rname)
    newver = norm(tag) if tag else None
    if not newver:
        unknown.append(repo)
        continue

    cur = {}      # per-package current version, preferring the spec
    for n in names:
        sv = spec_version(n)
        if sv is None:
            sv = str(pkgs[n].get("version", ""))
        cur[n] = sv
        if sv and str(pkgs[n].get("version", "")) != sv:
            drift.append((n, str(pkgs[n].get("version", "")), sv))

    # Bump any repo member that is behind the latest tag. Members that share a
    # repo normally move in lockstep, so this keeps owe + owe-lockfeed together
    # while never downgrading a member that is somehow ahead.
    for n in names:
        if semver(cur[n]) < semver(newver):
            plan.append((n, newver, cur[n], tag))

plan.sort(key=lambda r: r[0])
with open(plan_path, "w") as f:
    for name, newver, oldver, tag in plan:
        f.write(f"{name}\t{newver}\t{oldver}\t{tag}\n")

if plan:
    print(f"{'package':35} {'packaged':>10} {'latest':>10}  action")
    print("-" * 72)
    for name, newver, oldver, tag in plan:
        print(f"{name:35} {oldver:>10} {newver:>10}  BUMP -> {newver}-1")
else:
    print("all verified packages current")

if drift:
    print()
    print("warning: manifest/spec version drift (spec is authoritative; both get synced):")
    for name, mv, sv in drift:
        print(f"  {name}: manifest {mv} != spec {sv}")

if unknown:
    print()
    print("warning: could not determine latest upstream version for:")
    for repo in unknown:
        print(f"  {repo}")

sys.exit(0)
PY

if [ ! -s "$PLAN" ]; then
  echo
  echo "Nothing to do."
  exit 0
fi

if [ "$DRY_RUN" = 1 ]; then
  echo
  echo "(--dry-run: no files changed)"
  exit 0
fi

if [ "$ASSUME_YES" != 1 ]; then
  printf '\nApply these version bumps and submit to %s? [y/N] ' "$COPR"
  read -r reply || reply=""
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "aborted (no files changed)"; exit 0 ;;
  esac
fi

if ! python3 - "$RPM_DIR" "$MANIFEST" "$PLAN" "$MAINTAINER" >"$CHANGED_OUT" <<'PY'
import datetime, os, re, sys

rpm_dir, manifest_path, plan_path, fallback_maintainer = sys.argv[1:5]

plan = []
for line in open(plan_path):
    line = line.rstrip("\n")
    if not line:
        continue
    fields = line.split("\t")
    name, newver, oldver, tag = (fields + ["", "", "", ""])[:4]
    plan.append((name, newver, oldver, tag))

def read(path):
    with open(path) as f:
        return f.read()

def find_maintainer(src, fallback):
    m = re.search(r"(?m)^\*\s+\w+\s+\w+\s+\d+\s+\d+\s+(.+?)\s+-\s+\S+", src)
    return m.group(1).strip() if m else fallback

def update_manifest_version(text, pkg, new):
    out, in_pkg = [], False
    for line in text.splitlines(keepends=True):
        m = re.match(r"^  (\S+):\s*$", line)
        if m:
            in_pkg = (m.group(1) == pkg)
        if in_pkg:
            mv = re.match(r"^(\s+version:\s+)\S+", line)
            if mv:
                line = mv.group(1) + new + ("\n" if line.endswith("\n") else "")
        out.append(line)
    return "".join(out)

now = datetime.datetime.now()
date_str = f"{now.strftime('%a %b')} {now.day} {now.year}"

manifest_src = read(manifest_path)
writes = {}          # path -> new content (written only after every edit succeeds)
changed = []

for name, newver, oldver, tag in plan:
    spec_path = os.path.join(rpm_dir, name, name + ".spec")
    if not os.path.exists(spec_path):
        print(f"auto-update: no spec for {name}, skipping", file=sys.stderr)
        manifest_src = update_manifest_version(manifest_src, name, newver)
        continue

    src = writes.get(spec_path, read(spec_path))
    m = re.search(r"(?m)^Version:\s*(\S+)", src)
    if not m:
        print(f"auto-update: no Version: in {spec_path}, skipping", file=sys.stderr)
        continue

    cur = m.group(1)
    manifest_src = update_manifest_version(manifest_src, name, newver)

    if cur == newver:
        continue

    maintainer = find_maintainer(src, fallback_maintainer)
    new_src = re.sub(r"(?m)^(Version:\s+)\S+", r"\g<1>" + newver, src, count=1)
    new_src = re.sub(r"(?m)^(Release:\s+)\S+", r"\g<1>1%{?dist}", new_src, count=1)

    idx = new_src.find("%changelog")
    if idx == -1:
        print(f"auto-update: no %changelog in {spec_path}, skipping", file=sys.stderr)
        continue

    entry = f"* {date_str} {maintainer} - {newver}-1\n- Automatic update to upstream v{newver}\n\n"
    nl = new_src.find("\n", idx)
    new_src = new_src[:nl + 1] + entry + new_src[nl + 1:]

    writes[spec_path] = new_src
    changed.append(name)
    print(f"auto-update: {name} {cur} -> {newver}", file=sys.stderr)

if not changed and manifest_src == read(manifest_path):
    sys.exit(0)

for path, content in writes.items():
    with open(path, "w") as f:
        f.write(content)
with open(manifest_path, "w") as f:
    f.write(manifest_src)

print("\n".join(changed))
PY
then
  echo "auto-update: edit step failed; no files were changed" >&2
  exit 1
fi

CHANGED=()
while IFS= read -r pkg; do
  if [ -n "$pkg" ]; then CHANGED+=("$pkg"); fi
done < "$CHANGED_OUT"

if [ "${#CHANGED[@]}" -eq 0 ]; then
  echo
  echo "No spec versions changed (manifest version(s) synced; nothing to submit)."
  exit 0
fi

echo
echo "== updated: ${CHANGED[*]} =="

if [ "$VERIFY" = 1 ]; then
  echo "== container-verifying ${CHANGED[*]} =="
  bash "$CONTAINER_BUILD" "${CHANGED[@]}"
fi

submit_args=()
for c in "${CHROOTS[@]}"; do submit_args+=(--chroot "$c"); done
if [ "$SUBMIT_BUILDS" = 0 ]; then
  submit_args+=(--srpms-only)
fi

bash "$SUBMIT" "${submit_args[@]}" "${CHANGED[@]}"
