# CONTRIBUTING

Thanks for contributing to **Omarchy Fedora** — a Fedora adapter for Omarchy
Quattro.

## Core principles

1. **Upstream stays authoritative.** Never copy upstream desktop code into
   `fedora/`. Vendor upstream via `git subtree` (see UPSTREAM.md).
2. **Thin adapter.** Solve only Fedora-side problems here.
3. **No fork-and-diverge.** No `fedora/config/`, `fedora/themes/`,
   `fedora/shell/` duplicates of upstream.
4. **Prefer upstreamable abstractions.** If an abstraction benefits both Arch
   and Fedora (e.g. `omarchy_pkg_*`), propose it upstream rather than carrying
   a Fedora-only copy.
5. **No security bypass.** Never disable SELinux/systemd security/firewall to
   make something work.

## Change classification

Every upstream change you touch must be classified as one of:

1. Fedora-only → appropriate for the Fedora layer.
2. Distro-independent improvement → propose upstream.
3. Temporary compatibility patch → documented in `patches/README.md`, expected
   to disappear.

## Package changes

- Edit `fedora/mappings/packages.yaml` (and `repositories.yaml` if a new COPR).
- Never assume an Arch package == a Fedora package. Verify with
  `dnf info`, `dnf repoquery`, `dnf provides`.
- Every substitute needs a compatibility comment.

## Testing

- Run `bash fedora/tests/static.sh` before committing.
- Add offline tests where possible (syntax, mapping consistency).
- Destructive testing happens in a disposable Fedora VM, never a developer's
  daily system.

## Commits

Small, logically-separated commits, e.g.:

```
Add Fedora package abstraction
Add Fedora package mappings
Add Fedora COPR support
Add Fedora bootstrap
Add Fedora system integration
Add Quattro integration tests
Add upstream synchronization
```

## Reporting phases

At the end of each phase, update docs and report: Completed, Remaining, Known
incompatibilities, Upstream dependencies, Fedora-specific patches, Tests
passed/failed.
