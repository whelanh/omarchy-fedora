#!/usr/bin/env python3
"""Resolve Omarchy upstream package names to Fedora packages + sources.

Reads fedora/mappings/packages.yaml and emits the Fedora package list for a
given source classification (fedora, copr, rpmfusion, substitute, ...) or all.

Usage:
  resolve.py --source fedora            # print fedora + substitute dnf names
  resolve.py --copr <owner/name>        # packages from that copr
  resolve.py --package <arch-name>      # one lookup -> json
  resolve.py --all                      # dump full mapping json
"""

import json
import os
import sys

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
MAPPING = os.path.join(ROOT, "fedora", "mappings", "packages.yaml")


def load():
    with open(MAPPING) as f:
        return yaml.safe_load(f)["packages"]


def main():
    args = sys.argv[1:]
    data = load()

    if "--all" in args:
        print(json.dumps(data, indent=2))
        return

    if "--package" in args:
        name = args[args.index("--package") + 1]
        entry = data.get(name)
        if not entry:
            sys.exit(f"package not in mapping: {name}")
        print(json.dumps(entry, indent=2))
        return

    if "--source" in args:
        src = args[args.index("--source") + 1]
        for name, entry in data.items():
            if entry.get("source") == src and entry.get("package"):
                print(entry["package"])
        return

    if "--copr" in args:
        copr = args[args.index("--copr") + 1]
        for name, entry in data.items():
            if entry.get("source") == "copr" \
               and entry.get("repository") == copr \
               and entry.get("package"):
                print(entry["package"])
        return

    if "--build" in args:
        for name, entry in data.items():
            if entry.get("source") == "build":
                print(name)
        return

    # default: print all non-null Fedora names grouped by source
    groups = {}
    for name, entry in data.items():
        if not entry.get("package"):
            continue
        groups.setdefault(entry.get("source"), []).append(entry["package"])
    for src, pkgs in groups.items():
        print(f"[{src}]")
        for p in sorted(pkgs):
            print(f"  {p}")


if __name__ == "__main__":
    main()
