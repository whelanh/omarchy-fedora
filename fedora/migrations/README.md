# Fedora-native migrations

`omarchy update` runs the scripts in this directory exactly once each (as
root), in filename order, and records completion in
`/var/lib/omarchy-fedora/migrations/`. This is the Fedora equivalent of
upstream's Arch-specific `omarchy-migrate`, which we deliberately do **not**
run (its scripts call `omarchy-pkg-*`, a pacman wrapper).

## When to add one

Add a timestamped `.sh` script here when an upstream change needs a one-time
action on Fedora that `dnf upgrade` + the userspace tree sync can't do on
their own. The two cases are:

1. **Package removal/replacement** — when upstream drops or renames a package.
   The new package is added to the COPR + `fedora/packages/*.txt`, but dnf does
   not auto-remove the obsolete one, so a migration does it explicitly.
2. **Distro-neutral config migration** — when a user's *existing* config needs
   to be moved/rewritten to a new format (fresh installs are unaffected, but
   long-running installs need the transform).

## Example: upstream replaces `tensaku` with `newPackage`

1. Add a `newPackage` SPEC under `fedora/rpm/`, mark it `verified`, build +
   submit to the COPR.
2. Drop `tensaku` from `fedora/rpm/manifest.yaml`.
3. Add a migration here, e.g. `1789000000-replace-tensaku.sh`:

```sh
#!/bin/bash
# Replace tensaku (retired upstream) with newPackage.
set -euo pipefail
dnf -y remove tensaku
# newPackage is installed on the next dnf upgrade (or immediately):
dnf -y install newPackage
```

The timestamp (Unix epoch) determines run order and must increase; use
`date +%s`.

## Rules

- Scripts run as root (they are invoked with `sudo` from `omarchy update`).
- Use `set -euo pipefail`; a non-zero exit leaves no marker, so the script
  retries on the next update.
- Prefer `dnf` for package operations; never `pacman`/`yay`.
- Keep them idempotent where possible (they normally run once, but a marker
  could be lost if `/var/lib` is reset).
- Do not add a script for something the userspace tree sync already handles
  (new default config ships with the tree itself).
