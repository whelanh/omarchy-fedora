#!/usr/bin/env python3
"""Reconcile a spec's Release: with its newest %changelog entry.

A spec builds one NEVRA: `Version`-`Release`. The newest %changelog entry should
name that same version-release, because that is the entry describing what the
build contains. When the two disagree the file is lying about itself, and the
usual cause is a hand fix: someone edits the packaging, writes a `-2` changelog
entry, but leaves `Release:` at 1, so every rebuild still produces `-1` and the
entry never ships (omasnap 1.26.2 sat like that for a week).

States, from `analyze`:

  ok      the newest entry names Version-Release
  repair  the newest entry names the same Version with a *higher* Release:
          Release: simply lags the work already described, so raise it
  stale   anything else (an entry for another version, or a lower release,
          which means a version bump landed without a changelog entry). That
          cannot be inferred safely, so it is reported for a human.

Used by auto-update.sh, which repairs `repair` specs and submits them; the
static suite also asserts every spec in the tree is `ok`.

CLI:
  spec_release.py --check <spec>   print "state<TAB>version<TAB>release<TAB>top"
  spec_release.py --fix <spec>     print the spec with Release: raised to the
                                   newest entry's release (exit 1 if it cannot)
"""

import re
import sys

_ENTRY = re.compile(
    r"(?m)^\*\s+\w+\s+\w+\s+\d+\s+\d+\s+.+?\s+-\s+(\S+)\s*$")
_VERSION = re.compile(r"(?m)^Version:\s*(\S+)")
_RELEASE = re.compile(r"(?m)^(Release:\s*)(\d+)(\S*)")


def _split(el):
    """Split a changelog version-release into (version, release-number)."""
    if "-" not in el:
        return el, None
    version, release = el.rsplit("-", 1)
    return version, (int(release) if release.isdigit() else None)


def analyze(text):
    """Return the spec's state and the parts that decide it."""
    vm, rm, em = _VERSION.search(text), _RELEASE.search(text), _ENTRY.search(text)
    if not (vm and rm and em):
        raise ValueError("no Version:, numeric Release: or %changelog entry")
    version, release, top = vm.group(1), int(rm.group(2)), em.group(1)
    top_version, top_release = _split(top)
    if top == "%s-%d" % (version, release):
        state = "ok"
    elif top_version == version and top_release is not None and top_release > release:
        state = "repair"
    else:
        state = "stale"
    return {
        "state": state,
        "version": version,
        "release": release,
        "top": top,
        "top_version": top_version,
        "top_release": top_release,
    }


def fix_text(text):
    """Raise Release: to the newest entry's release. Returns (text, info)."""
    info = analyze(text)
    if info["state"] != "repair":
        raise ValueError("not repairable: state is %s (top entry %s)" %
                         (info["state"], info["top"]))
    new_text = _RELEASE.sub(
        lambda m: "%s%d%s" % (m.group(1), info["top_release"], m.group(3)),
        text, count=1)
    return new_text, info


def main(argv):
    if len(argv) != 2 or argv[0] not in ("--check", "--fix"):
        print(__doc__.strip().splitlines()[-4].strip(), file=sys.stderr)
        return 2
    try:
        text = open(argv[1]).read()
    except OSError as e:
        print(e, file=sys.stderr)
        return 2
    if argv[0] == "--check":
        try:
            info = analyze(text)
        except ValueError as e:
            print(e, file=sys.stderr)
            return 2
        print("%s\t%s\t%d\t%s" % (info["state"], info["version"],
                                  info["release"], info["top"]))
        return 0 if info["state"] == "ok" else 1
    try:
        new_text, info = fix_text(text)
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    sys.stdout.write(new_text)
    print("spec_release: %s Release %d -> %d" %
          (info["version"], info["release"], info["top_release"]),
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
