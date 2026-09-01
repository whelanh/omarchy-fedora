# Ongoing Update & Maintenance

How to keep the Omarchy-on-Fedora port current as upstream Omarchy evolves.
This covers the two jobs `omarchy update` does **not** automate for you:

1. keeping the **first-party COPR packages** current with upstream releases, and
2. reacting when upstream **adds, removes, or replaces a package**.

> You (the Fedora port maintainer) are the human in the loop. `omarchy update`
> handles the *userspace tree* (via a `quattro` sync) and *Fedora packages*
> (via `dnf upgrade`). Everything below is about the changes upstream makes
> that those two mechanisms can't pick up on their own.

---

## How you'll notice upstream changed something

There are four signals, roughly in order of how much they automate the work:

### 1. The daily `upstream-sync` GitHub workflow

`.github/workflows/upstream-sync.yml` runs daily and opens a **SAFE PR** whenever
the vendored `upstream/` `quattro` subtree changes. That PR's diff is your review
surface. A "replace X with Y" change shows up as files added/removed, plus the
new migration's summary line. Review it for package changes.

### 2. The CI static test fails on unmapped packages

`fedora/tests/static.sh` asserts that every entry in
`upstream/install/omarchy-base.packages` has a `packages.yaml` mapping. If
upstream *adds* a base package you haven't mapped, CI goes red with:

```
FAIL  mapped: <newpkg>
```

That is a concrete, automated "you need to map a new package" signal.
(Package *removals* are quieter — a stale mapping is harmless until you clean
it up.)

### 3. `check-updates.sh` (two modes)

```sh
# version drift for the 10 first-party COPR packages
bash fedora/rpm/copr/check-updates.sh

# package add/remove drift vs our mapping
bash fedora/rpm/copr/check-updates.sh --packages
```

`--packages` diffs upstream's `omarchy-base.packages` + `omarchy-other.packages`
against `fedora/mappings/packages.yaml` and prints:

- **unmapped** — upstream ships a package we have no mapping for yet
- **stale** — we map a package upstream no longer lists

### 4. Upstream migration summaries

Upstream's migrations (in `upstream/migrations/`) are Arch-specific, so we don't
run them — but each begins with a human-readable `echo "..."` summary line. The
migration directory effectively doubles as a changelog of "things that changed
between versions".

---

## Where a new/changed package actually comes from

Most package changes are **not** COPR builds. Resolve a package in this order:

| Priority | Source | What you do |
|----------|--------|-------------|
| 1 | **Fedora official** | add a `packages.yaml` entry (`source: fedora`) + a line in a `fedora/packages/*.txt` |
| 2 | **Existing COPR / RPM Fusion** (`nett00n/hyprland`, `atim/*`, RPM Fusion) | same, plus the repo is already enabled |
| 3 | **Flathub** | `source: flatpak` with the app id |
| 4 | **Omarchy's own first-party binary** (aether, cliamp, herdr, omacalc, omacut, omawrite, tensaku, ttfx, and future Omarchy-authored tools) | write a SPEC under `fedora/rpm/`, mark it `verified`, build + submit to `whelanh/omarchy` |

Only row 4 requires building in the `whelanh/omarchy` COPR. Everything else is a
mapping + package-list entry. (Examples already shipped this way: `qrencode`,
`ddcutil`, `zbar`, `dua→dua` are plain Fedora mappings; `tensaku`/`ttfx` are
COPR first-party.)

---

## Playbook: upstream replaces package `X` with `Y`

1. **Determine where `Y` comes from** using the table above.
2. If `Y` is first-party → add a SPEC, mark `verified`, build + submit:
   ```sh
   bash fedora/rpm/copr/submit-builds.sh Y
   ```
3. If `X` was first-party → remove it from `fedora/rpm/manifest.yaml` (and drop
   its spec). `dnf` never auto-removes a package just because you stop building
   it, so also add a migration to uninstall it from existing systems:
   ```sh
   # fedora/migrations/<date +%s>-replace-X.sh
   #!/bin/bash
   set -euo pipefail
   dnf -y remove X
   ```
   See `fedora/migrations/README.md`.
4. Add/update the `packages.yaml` mapping for `Y`, and update any
   `fedora/packages/*.txt` lists.
5. Verify: `./fedora/tests/static.sh` and `bash fedora/rpm/copr/check-updates.sh --packages`.

---

## Bumping a first-party package to a newer release

1. `bash fedora/rpm/copr/check-updates.sh` to see what's out of date.
2. In `fedora/rpm/<pkg>/<pkg>.spec`: bump `Version:`, reset `Release:` to `1`,
   and add a `%changelog` entry (or bump `Release:` only if it's a packaging
   fix with no upstream change).
3. Container-verify: `bash fedora/rpm/build-rpm-in-ci.sh <pkg>`.
4. Submit: `bash fedora/rpm/copr/submit-builds.sh <pkg>`.
5. Watch: `copr-cli list-builds whelanh/omarchy --output-format text`.

---

## New Fedora release

COPR does not carry packages to a new chroot automatically:

```sh
copr-cli modify whelanh/omarchy --chroot fedora-<N>-x86_64
bash fedora/rpm/copr/submit-builds.sh      # rebuild all 10 into the new chroot
```
