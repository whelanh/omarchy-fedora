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
#   fedora/rpm/copr/auto-update.sh --no-prune-retired  # skip deleting retired COPR packages
#   fedora/rpm/copr/auto-update.sh --no-packages-check # skip the upstream add/remove drift report
#   fedora/rpm/copr/auto-update.sh --no-rebuilds   # don't auto-rebuild rebuild_on dependents
#   fedora/rpm/copr/auto-update.sh --no-watch       # submit, don't watch/self-heal
#   fedora/rpm/copr/auto-update.sh --chroot fedora-45-x86_64
#
# Notes:
#   - Only packages with `status: verified` in manifest.yaml are considered;
#     the others are not part of the COPR. The plan prints every one of them
#     with its packaged and latest version, so a run that changes nothing still
#     shows each package was checked (`ok`, `HELD`, `SKIPPED`). A repo with no
#     releases and no tags is listed as `(no releases or tags)`; a GitHub API
#     failure aborts the run instead of being reported as "unknown".
#     `(manual)` rows are the vendor-URL packages the updater cannot follow.
#   - Runs `check-updates.sh --packages` and warns about new upstream package
#     add/remove drift (unmapped or stale mappings). Rows accepted in
#     fedora/mappings/package-audit-baseline.conf are suppressed, so only new
#     drift is reported. Mapping/retirement is a manual task, so it warns but
#     does not block the bumps.
#   - A package with `rebuild_on:` is rebuilt (Release: bumped, Version:
#     unchanged) when its trigger's latest successful COPR build is newer than
#     the package's own. This covers native plugins such as
#     omarchy-hyprland-titlebars, whose ABI hash follows hyprland-devel even
#     when the plugin's upstream version has not moved.
#   - delete-retired.sh removes the packages named in retired-packages.conf
#     from the COPR (a retired package is gone from fedora/rpm/ + manifest.yaml,
#     so nothing else here touches it, but the COPR keeps it until deleted).
#     This is ON by default; --no-prune-retired skips it. Best-effort: a prune
#     failure warns, never blocks. Skipped with --srpms-only, and previewed with
#     --dry-run.
#   - The submit step watches the COPR builds and self-heals chroots that failed
#     for a recognised transient reason (e.g. the nett00n/hyprland build repo
#     briefly 404ing while COPR's Pulp mirror resyncs), a bounded number of
#     times. Real failures are reported, never retried. --no-watch restores the
#     old fire-and-forget behaviour; COPR_RETRIES / COPR_RETRY_DELAY tune the
#     retry budget.
#   - Packages that share an upstream repo (owe + owe-lockfeed) are bumped
#     together to the same version.
#   - The current version is read from each spec, not the manifest, so a stale
#     manifest cannot hide a needed bump. Both are written on success.
#   - A bump is skipped when the new release is missing a file the spec
#     packages (HTTP 404/410 on a Source: URL). Upstream sometimes tags a
#     release before publishing its platform builds — voxtype v1.2.0 shipped
#     macOS-only because its Linux workflow failed — which would otherwise bump
#     the spec and fail the SRPM build with nothing submitted.
#   - All file edits happen in memory and are only written once every edit has
#     succeeded, so a failure never leaves a half-bumped tree.
#   - The maintainer identity in new %changelog entries is taken from the
#     spec's existing entry (falling back to git config / OMARCHY_RPM_MAINTAINER).
#   - Also runs `check-updates.sh --pins` and warns about specs whose
#     omarchy-pkgs commit pin (launcher/service/desktop/key/setup files) is now
#     stale. That is a manual review, so it warns but does not block the bumps.
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
  auto-update.sh --no-prune-retired   skip deleting retired packages from the COPR
  auto-update.sh --no-packages-check  skip the upstream add/remove drift report
  auto-update.sh --no-rebuilds    don't auto-rebuild rebuild_on dependents
  auto-update.sh --no-watch       submit but don't watch/retry COPR builds
  auto-update.sh --chroot <name>  submit to only this chroot (repeatable)
EOF
}

DRY_RUN=0
ASSUME_YES=0
SUBMIT_BUILDS=1
VERIFY=0
PRUNE_RETIRED=1
PACKAGES_CHECK=1
REBUILD_DEPENDENTS=1
NO_WATCH=0
CHROOTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --srpms-only|--no-submit) SUBMIT_BUILDS=0 ;;
    --verify)     VERIFY=1 ;;
    --prune-retired) PRUNE_RETIRED=1 ;;
    --no-prune-retired) PRUNE_RETIRED=0 ;;
    --no-packages-check) PACKAGES_CHECK=0 ;;
    --no-rebuilds) REBUILD_DEPENDENTS=0 ;;
    --no-watch)   NO_WATCH=1 ;;
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
REBUILD_PLAN="$(mktemp)"
CHANGED_OUT="$(mktemp)"
trap 'rm -f "$PLAN" "$REBUILD_PLAN" "$CHANGED_OUT"' EXIT

# Authenticate through the GitHub CLI when it is already logged in. The
# unauthenticated API allows 60 requests/hour and a run needs one per upstream
# repo (~28), so a run that exhausts the window ends with every later package
# as "(unknown)" - which looks like the update check did nothing.
GH_AUTH=""
if [ -z "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
  if _gh_token="$(gh auth token 2>/dev/null)" && [ -n "$_gh_token" ]; then
    GH_TOKEN="$_gh_token"
    export GH_TOKEN
    GH_AUTH=" via gh"
  fi
fi

if [ -n "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]; then
  echo "== checking upstream for verified packages in $COPR (authenticated$GH_AUTH) =="
else
  echo "== checking upstream for verified packages in $COPR =="
  echo "   (tip: authenticate with 'gh auth login' or export GITHUB_TOKEN/GH_TOKEN;"
  echo "    the unauthenticated API allows only 60 requests/hour)"
fi
python3 - "$RPM_DIR" "$MANIFEST" "$PLAN" <<'PY'
import json, os, re, sys, urllib.error, urllib.request, yaml

rpm_dir, manifest_path, plan_path = sys.argv[1], sys.argv[2], sys.argv[3]
UA = {"User-Agent": "omarchy-fedora-auto-update", "Accept": "application/vnd.github+json"}
# Optional token raises the unauthenticated GitHub API limit from 60 to 5000
# requests/hour (one call per upstream repo). This script exports one from
# `gh auth token` when the environment has neither GITHUB_TOKEN nor GH_TOKEN;
# without a token a rate-limited run stops instead of reporting unknown.
_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
if _token:
    UA["Authorization"] = f"Bearer {_token}"

class ApiError(Exception):
    """A GitHub API call that could not be answered (HTTP status or transport)."""

    def __init__(self, url, code, detail=""):
        self.url, self.code, self.detail = url, code, detail
        super().__init__(f"HTTP {code} from {url}" if code else f"{detail or 'no response'} ({url})")

def gh_get(url):
    req = urllib.request.Request(url, headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise ApiError(url, e.code) from e
    except Exception as e:
        raise ApiError(url, None, str(e)) from e

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
    # Prefer the maintainer's "latest release". The full tag list can contain
    # unrelated or prefixed tags (e.g. openai/codex also publishes `rusty-v8-*`),
    # which makes picking the max by semver meaningless and can select a bogus
    # version.
    base = f"https://api.github.com/repos/{owner}/{repo}"
    try:
        data = gh_get(base + "/releases/latest")
        if isinstance(data, dict) and data.get("tag_name"):
            return data["tag_name"]
    except ApiError as e:
        # 404: the repo has no published release, which is normal - not a
        # failure. Anything else (403 rate limit, network) must not be read as
        # "no newer version".
        if e.code != 404:
            raise
    # No published release: fall back to the newest tag.
    cand = set()
    try:
        data = gh_get(base + "/tags?per_page=50")
        if isinstance(data, list):
            for t in data:
                if t.get("name"):
                    cand.add(t["name"])
    except ApiError as e:
        if e.code != 404:
            raise
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

def spec_sources(name):
    """HTTP(S) Source: URLs of a spec, macros still unexpanded."""
    path = os.path.join(rpm_dir, name, name + ".spec")
    try:
        src = open(path).read()
    except FileNotFoundError:
        return []
    m = re.search(r"(?m)^URL:\s*(\S+)", src)
    base = m.group(1) if m else ""
    urls = []
    for url in re.findall(r"(?m)^Source\d*:\s*(\S+)", src):
        if re.match(r"https?://", url):
            urls.append(url.replace("%{url}", base))
    return urls

def http_status(url):
    """HEAD status for url, or None when it could not be reached at all."""
    url = url.split("#", 1)[0]
    req = urllib.request.Request(url, method="HEAD",
                                 headers={"User-Agent": UA["User-Agent"]})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return None

def missing_sources(name, version):
    """Split the spec's sources at `version` into (missing, unverified).

    `missing` holds URLs answering 404/410, i.e. files this spec packages that
    upstream's release does not have. Upstream sometimes publishes a tag before
    (or without) the platform builds: voxtype v1.2.0 went out macOS-only because
    its Linux workflow failed, so bumping the repack would just fail the SRPM
    build and leave a bumped tree behind. `unverified` holds URLs that could not
    be checked (network error, 5xx); those are reported but never block a bump.
    """
    missing, unverified = [], []
    for raw in spec_sources(name):
        url = raw.replace("%{version}", version).replace("%{name}", name).split("#", 1)[0]
        code = http_status(url)
        if code in (404, 410):
            missing.append((url, code))
        elif code is None or code >= 500:
            unverified.append((url, code))
    return missing, unverified

REPO_RE = re.compile(r"https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$")

d = yaml.safe_load(open(manifest_path))
pkgs = d["packages"]

# `hold:` pins a package at its packaged version, with the reason as its value.
# Use it when upstream's new release needs something we cannot get yet (a newer
# hyprland, a distro that does not ship the library, ...): bumping anyway just
# fails the COPR build on every run. Drop the key once the blocker clears.
held = {n: str(p["hold"]).strip() for n, p in sorted(pkgs.items()) if p.get("hold")}

# verified packages grouped by their upstream repo
by_repo = {}
for name, p in sorted(pkgs.items()):
    if p.get("status") != "verified":
        continue
    m = REPO_RE.match(p.get("repo", "") or "")
    if m:
        by_repo.setdefault(p["repo"], []).append(name)

plan, unknown, drift = [], [], []
blocked, unverified = [], []
# One row per verified package for the checklist below, so a run that changes
# nothing still shows every package was checked (and why any was skipped).
rows = []

def explain_api_failure(err):
    print(f"error: GitHub API request failed: {err}", file=sys.stderr)
    if err.code == 401:
        print("       The token was rejected. Log in again (`gh auth login`) or set", file=sys.stderr)
        print("       a valid GITHUB_TOKEN/GH_TOKEN.", file=sys.stderr)
    elif err.code in (403, 429):
        print("       Rate limited or forbidden. The unauthenticated API allows only", file=sys.stderr)
        print("       60 requests/hour; authenticate with `gh auth login` or export", file=sys.stderr)
        print("       GITHUB_TOKEN/GH_TOKEN.", file=sys.stderr)
    else:
        print("       Network or GitHub problem; re-run once it recovers.", file=sys.stderr)
    print("       Continuing would report unchecked packages as unknown, so nothing", file=sys.stderr)
    print("       was changed.", file=sys.stderr)

api_error = None
for repo, names in sorted(by_repo.items()):
    owner, rname = REPO_RE.match(repo).groups()
    try:
        tag = latest_github(owner, rname)
    except ApiError as e:
        api_error = (repo, e)
        break
    newver = norm(tag) if tag else None
    if not newver:
        unknown.append(repo)
        for n in names:
            sv = spec_version(n) or str(pkgs[n].get("version", ""))
            rows.append((n, sv, None, "(no releases or tags)"))
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
    # while never downgrading a member that is somehow ahead. Held members are
    # skipped: their blocker is a dependency, not a version bump.
    for n in names:
        if n in held:
            rows.append((n, cur[n], tag, f"HELD ({held[n]})"))
            continue
        if semver(cur[n]) < semver(newver):
            # Never bump to a release whose files are not all published: the
            # SRPM build is the first thing that would notice, and by then the
            # spec is already bumped (auto-update writes before submitting).
            missing, unverifiable = missing_sources(n, newver)
            unverified.extend((n, url, code) for url, code in unverifiable)
            if missing:
                blocked.append((n, cur[n], newver, missing))
                rows.append((n, cur[n], tag, "SKIPPED (source 404)"))
                continue
            plan.append((n, newver, cur[n], tag))
            rows.append((n, cur[n], tag, f"BUMP -> {newver}-1"))
        else:
            ahead = semver(cur[n]) > semver(newver)
            rows.append((n, cur[n], tag, "ok (ahead of latest release)" if ahead else "ok"))

if api_error:
    repo, err = api_error
    explain_api_failure(err)
    print(f"error: could not check {repo}; nothing was bumped or submitted.", file=sys.stderr)
    sys.exit(2)

# Verified packages with no GitHub repo (a vendor download URL) cannot be
# followed automatically, but they still belong in the checklist.
for n, p in sorted(pkgs.items()):
    if p.get("status") == "verified" and not REPO_RE.match(p.get("repo", "") or ""):
        rows.append((n, spec_version(n) or str(p.get("version", "")), None,
                     "(manual)"))

plan.sort(key=lambda r: r[0])
with open(plan_path, "w") as f:
    for name, newver, oldver, tag in plan:
        f.write(f"{name}\t{newver}\t{oldver}\t{tag}\n")

rows.sort(key=lambda r: r[0])
print(f"{'package':35} {'packaged':>10} {'latest':>10}  status")
print("-" * 72)
for name, oldver, tag, status in rows:
    print(f"{name:35} {oldver:>10} {str(tag or '?'):>10}  {status}")

current = sum(1 for r in rows if r[3].startswith("ok"))
print()
if plan:
    print(f"{len(plan)} of {len(rows)} package(s) to bump")
elif held or blocked or unknown:
    print(f"nothing to bump ({len(held) + len(blocked) + len(unknown)} package(s) need review, below)")
elif current == len(rows):
    print(f"all {len(rows)} package(s) current")
else:
    manual = len(rows) - current
    print(f"all {current} tracked package(s) current ({manual} manual)")

if held:
    print()
    print("held at the packaged version (blocked on a dependency, not a version):")
    for name, why in held.items():
        print(f"  {name}: {why}")

if blocked:
    print()
    print("skipped: the upstream release is missing files this package needs")
    print("(staying at the packaged version until upstream publishes them):")
    for name, oldver, newver, missing in blocked:
        url, code = missing[0]
        more = f" (+{len(missing) - 1} more)" if len(missing) > 1 else ""
        print(f"  {name}: {oldver} -> {newver}  HTTP {code} {url}{more}")
    print("  If the release is permanently partial, add `hold:` to its")
    print("  manifest.yaml entry instead of retrying every run.")

if unverified:
    print()
    print("warning: could not verify these sources (bumping anyway; a 404 there")
    print("would fail the SRPM build):")
    for name, url, code in unverified:
        print(f"  {name}: HTTP {code or 'no response'} {url}")

if drift:
    print()
    print("warning: manifest/spec version drift (spec is authoritative; both get synced):")
    for name, mv, sv in drift:
        print(f"  {name}: manifest {mv} != spec {sv}")

if unknown:
    print()
    print("warning: upstream publishes no GitHub release or tag to compare against:")
    for repo in unknown:
        print(f"  {repo}")

sys.exit(0)
PY

# Surface new upstream package add/remove drift. Unmapped packages need a
# packages.yaml entry; stale mappings need retiring (or a baseline row). This is
# a manual mapping task, so warn but do not block the version bumps.
if [ "$PACKAGES_CHECK" = 1 ]; then
  echo
  echo "== checking upstream package add/remove drift =="
  if ! bash "$COP_DIR/check-updates.sh" --packages; then
    echo
    echo "NOTE: new upstream package drift — map added packages and retire removed"
    echo "      ones (fedora/mappings/packages.yaml + retired-packages.conf). If an"
    echo "      accepted gap should stay, add it to"
    echo "      fedora/mappings/package-audit-baseline.conf with a reason."
  fi
fi

# Surface stale omarchy-pkgs commit pins (auxiliary files pinned in a spec).
# These need a manual review, not a version bump, so warn but do not block.
echo
echo "== checking omarchy-pkgs commit pins =="
if ! bash "$COP_DIR/check-updates.sh" --pins; then
  echo
  echo "NOTE: pinned omarchy-pkgs files changed upstream — review the diff, update"
  echo "      the commit SHA in the affected spec, bump Release: + a %changelog"
  echo "      entry, and resubmit that package."
fi

# Native plugins (titlebars) are tied to their trigger's headers, not just their
# own version. Rebuild them when the trigger's latest successful COPR build is
# newer; a package already in the version plan is rebuilt by that bump anyway.
if [ "$REBUILD_DEPENDENTS" = 1 ]; then
  echo
  echo "== checking rebuild_on dependents =="
  RAW_REBUILDS="$(mktemp)"
  rc=0
  bash "$COP_DIR/check-updates.sh" --rebuilds --porcelain >"$RAW_REBUILDS" 2>/dev/null || rc=$?
  if [ "$rc" -ne 0 ] && [ ! -s "$RAW_REBUILDS" ]; then
    echo "NOTE: could not compare rebuild_on dependents (COPR API/network); continuing."
    : >"$RAW_REBUILDS"
  fi
  python3 - "$PLAN" "$RAW_REBUILDS" "$REBUILD_PLAN" <<'PY'
import sys
versioned = {line.split("\t")[0] for line in open(sys.argv[1]) if line.strip()}
out = []
for line in open(sys.argv[2]):
    line = line.rstrip("\n")
    if not line:
        continue
    name = line.split("\t")[0]
    if name and name not in versioned:
        out.append(line)
open(sys.argv[3], "w").write("\n".join(out) + ("\n" if out else ""))
PY
  rm -f "$RAW_REBUILDS"
  if [ -s "$REBUILD_PLAN" ]; then
    printf '\n%s\n' "rebuild needed (Version: unchanged; Release: bumped):"
    while IFS=$'\t' read -r name trigger; do
      printf '  %-34s REBUILD against %s\n' "$name" "$trigger"
    done <"$REBUILD_PLAN"
  else
    echo "all rebuild_on dependents are newer than their trigger builds"
  fi
fi

# Retired packages are gone from fedora/rpm/ + manifest.yaml, so no other step
# here touches them — but the COPR keeps the source package and its build
# history until deleted. delete-retired.sh removes them (retired-packages.conf);
# this runs by default (--no-prune-retired skips it) and is best-effort so a
# login/network hiccup never blocks the version bumps.
if [ "$PRUNE_RETIRED" = 1 ]; then
  echo
  if [ "$SUBMIT_BUILDS" = 0 ]; then
    echo "== --srpms-only: skipping COPR prune of retired packages =="
  elif [ "$DRY_RUN" = 1 ]; then
    echo "== retired packages that would be pruned from $COPR =="
    bash "$COP_DIR/delete-retired.sh" --dry-run || \
      echo "NOTE: COPR prune preview failed (see above); continuing." >&2
  else
    echo "== pruning retired packages from $COPR =="
    bash "$COP_DIR/delete-retired.sh" || \
      echo "NOTE: COPR prune failed (see above); continuing." >&2
  fi
fi

if [ ! -s "$PLAN" ] && [ ! -s "$REBUILD_PLAN" ]; then
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
  printf '\nApply these updates and submit to %s? [y/N] ' "$COPR"
  read -r reply || reply=""
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "aborted (no files changed)"; exit 0 ;;
  esac
fi

if ! python3 - "$RPM_DIR" "$MANIFEST" "$PLAN" "$REBUILD_PLAN" "$MAINTAINER" >"$CHANGED_OUT" <<'PY'
import datetime, os, re, sys

rpm_dir, manifest_path, plan_path, rebuild_path, fallback_maintainer = sys.argv[1:6]

plan = []
for line in open(plan_path):
    line = line.rstrip("\n")
    if not line:
        continue
    fields = line.split("\t")
    name, newver, oldver, tag = (fields + ["", "", "", ""])[:4]
    plan.append((name, newver, oldver, tag))

rebuilds = []
for line in open(rebuild_path):
    line = line.rstrip("\n")
    if not line:
        continue
    fields = line.split("\t")
    name = fields[0]
    trigger = fields[1] if len(fields) > 1 else ""
    if name:
        rebuilds.append((name, trigger or "an updated build dependency"))

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

versioned = {name for name, *_ in plan}
for name, trigger in rebuilds:
    if name in versioned:
        continue

    spec_path = os.path.join(rpm_dir, name, name + ".spec")
    if not os.path.exists(spec_path):
        print(f"auto-update: no spec for {name}, skipping rebuild", file=sys.stderr)
        continue

    src = writes.get(spec_path, read(spec_path))
    vm = re.search(r"(?m)^Version:\s*(\S+)", src)
    rm = re.search(r"(?m)^Release:\s+(\d+)", src)
    if not vm or not rm:
        print(f"auto-update: no Version:/Release: in {spec_path}, skipping rebuild", file=sys.stderr)
        continue

    version, newrel = vm.group(1), int(rm.group(1)) + 1
    maintainer = find_maintainer(src, fallback_maintainer)
    new_src = re.sub(r"(?m)^(Release:\s+)\d+", r"\g<1>" + str(newrel), src, count=1)

    idx = new_src.find("%changelog")
    if idx == -1:
        print(f"auto-update: no %changelog in {spec_path}, skipping rebuild", file=sys.stderr)
        continue

    entry = (f"* {date_str} {maintainer} - {version}-{newrel}\n"
             f"- Automatic rebuild against {trigger}: native plugin ABI follows its COPR build dependency\n\n")
    nl = new_src.find("\n", idx)
    new_src = new_src[:nl + 1] + entry + new_src[nl + 1:]

    writes[spec_path] = new_src
    changed.append(name)
    print(f"auto-update: {name} rebuilt ({version}-{newrel}) against {trigger}", file=sys.stderr)

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
if [ "$NO_WATCH" = 1 ]; then
  submit_args+=(--no-watch)
fi

bash "$SUBMIT" "${submit_args[@]}" "${CHANGED[@]}"
