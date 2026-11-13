#!/usr/bin/env python3
"""Hand a legacy default dock back to upstream's default pins.

Upstream commit 00147cf6d ("Pin Omarchy's own apps in the default dock",
2026-11-12, #18667) changed the pins shipped in config/omarchy/shell.json:

    before: folio/browser, foot, omacalc, omawrite, X, YouTube
    after:  folio, omarchy-browser, omarchy-terminal, omacalc, omawrite,
            hype, monologue, cliamp

It shipped no migration, so any machine that had already copied the old list
into ~/.config/omarchy/shell.json keeps it. The Fedora port makes that
permanent: install.sh seeds ~/.config once with `cp -a -n`, so the dock freezes
at install time (see fedora/migrations/*-dock-pins-follow-defaults.sh).

Removing dock.pinned, rather than pasting the new list, is the fix: the shell
falls back to the packaged default when the key is absent
(DockModel.pinnedIds(config, defaults)), so the dock tracks upstream's defaults
from then on. Only the exact shipped list (same ids, same order) is touched -
anything else is the user's own dock.

Usage:
  dock-pins.py --check FILE   exit 0 when FILE still holds a legacy default
  dock-pins.py --fix FILE     drop dock.pinned when it is a legacy default
                              (exit 0 changed, 1 not a legacy default)
  dock-pins.py --show FILE    print dock.pinned, one id per line (debugging)
"""

import json
import sys

# Every default upstream shipped between "Add a dock to floating workspaces"
# (124328fd8) and #18667, plus the port's own October seed, which predates the
# chromium line those snapshots carry (hence the shorter variants).
LEGACY_DEFAULTS = (
    ("org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"),
    ("org.gnome.Nautilus", "google-chrome", "foot", "omacalc", "omawrite", "X", "YouTube"),
    ("org.gnome.Nautilus", "foot", "omacalc", "omawrite", "X", "YouTube"),
    ("folio", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"),
    ("folio", "google-chrome", "foot", "omacalc", "omawrite", "X", "YouTube"),
    ("folio", "foot", "omacalc", "omawrite", "X", "YouTube"),
)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def pins(config):
    """The dock's pinned list, or None when the key is absent or malformed."""
    dock = config.get("dock")
    if not isinstance(dock, dict):
        return None
    pinned = dock.get("pinned")
    if not isinstance(pinned, list) or not all(isinstance(p, str) for p in pinned):
        return None
    return pinned


def is_legacy_default(config):
    pinned = pins(config)
    if pinned is None:
        return False
    # Order-sensitive on purpose: dragging an icon in the dock rewrites the pins
    # in the user's order, so a reordered list is a customization even when it
    # holds the same apps.
    return tuple(pinned) in LEGACY_DEFAULTS


def main(argv):
    if len(argv) != 3 or argv[1] not in ("--check", "--fix", "--show"):
        print("usage: dock-pins.py --check|--fix|--show FILE", file=sys.stderr)
        return 2

    mode, path = argv[1], argv[2]
    try:
        config = load(path)
    except (OSError, ValueError) as err:
        print("dock-pins: %s: %s" % (path, err), file=sys.stderr)
        return 2

    if mode == "--show":
        for p in pins(config) or ():
            print(p)
        return 0

    if not is_legacy_default(config):
        return 1
    if mode == "--check":
        return 0

    del config["dock"]["pinned"]
    # Truncate in place: keeps the file's inode, owner, mode and any symlink.
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(config, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
