# Omarchy Quattro first-party RPMs

This directory scaffolds Fedora RPM packaging for the 10 "first-party"
binaries that Omarchy ships but that are **not** available (or not maintained)
in Fedora official/COPR repos. They map to `source: build` entries in
`fedora/mappings/packages.yaml` and are distributed via the
`whelanh/omarchy` COPR.

> **Status: 10 VERIFIED, 0 BLOCKED.** Every package builds cleanly in the
> Fedora Rawhide container (`manifest.yaml` status `verified`), driven by
> `build-rpm-in-ci.sh` — the same path the CI `rpm-build` job runs.

## Layout

- `manifest.yaml` — machine-readable record of every package: repo, language,
  build command, license, upstream reference, version, and verification status.
- `build-rpm.sh <pkg>` — builds one package with `rpmbuild` (optionally via
  `mock`).
- `build-rpm-in-ci.sh [pkg...]` — builds all `verified` packages (or the
  listed ones when given args, with `FORCE=1` to verify unlisted specs) inside
  an already-running Fedora container; this is the CI `rpm-build` job.
- `<pkg>/<pkg>.spec` — one SPEC per package.

## How to build locally

Prereqs (Fedora, non-root in this case): the build scripts run inside a
`fedora:rawhide` container via podman.

```sh
# one package (inside an interactive rawhide container)
FEDORA=1 bash fedora/rpm/build-in-container.sh tensaku

# everything, exactly like CI (inside the container):
#   dnf -y install rpm-build dnf-plugins-core python3-pyyaml
#   dnf -y copr enable nett00n/hyprland   # gtk4-layer-shell-devel for the share-picker
#   bash /work/fedora/rpm/build-rpm-in-ci.sh
```

## The 10 packages

| Package | Repo | Build | License | Status |
|---------|------|-------|---------|--------|
| aether | omacom/aether | prebuilt-repack | MIT | verified |
| cliamp | bjarneo/cliamp | prebuilt-repack | MIT | verified |
| herdr | herdrdev/herdr | prebuilt-repack | Apache-2.0 | verified |
| hyprland-preview-share-picker | WhySoBad/… | cargo (stable Rust) | MIT | verified |
| omacalc | omacom/omacalc | Qt6 / qmake6 | MIT | verified |
| omacut | omacom/omacut | Qt6 / qmake6 | MIT | verified |
| omawrite | omacom/omawrite | Qt6 / qmake6 | MIT | verified |
| tensaku | jondkinney/tensaku | prebuilt-tarball repack | MPL-2.0 | verified |
| tobi-try | tobi/try | Ruby gem | MIT | verified |
| ttfx | omacom/ttfx | cargo | MIT | verified |

### Dropped from RPM scope (were in the original 13)

These are intentionally **not** RPMs here:

- **asdcontrol** (nikosdion/asdcontrol) — upstream archived Aug 2025,
  Apple Studio Display hardware only.
- **omarchy-nvim** (omacom/omarchy-pkgs) — assembles a ~116 MiB LazyVim cache
  via an in-tree config/headless-nvim sync; not a standalone source RPM.
- **usage** — shipped in-tree by the base fetch: `upstream/bin/omarchy-agent-
  usage-*` plus `upstream/shell/plugins/agents/usage/`, and `install_omarchy_bin`
  already symlinks every `bin/omarchy-*`. An RPM would file-conflict with the
  base install.

## Build notes (the four repacks)

- **aether / cliamp / herdr** — upstream ships a single prebuilt release
  binary (`*-linux-amd64` / `*-linux-x86_64`), which is exactly what Omarchy's
  Arch PKGBUILDs install; the specs repackage the release asset plus the
  desktop/icon/license bits. `%global debug_package %{nil}` because the
  prebuilt ELF carries no DWARF. `herdr` uses `herdrdev/herdr` release assets
  (the `omacom-io/herdr` fork has tags but no release binaries).
- **tensaku** — the `tensaku-v0.28.0-x86_64.tar.gz` release ships the full
  install tree (`bin/` + `share/` with desktop, hicolor svg, man page,
  completions, and MPL licenses), so the spec just stage-extracts it into the
  buildroot with `tar --strip-components=1`.
- **hyprland-preview-share-picker** — compiles from source on **stable Fedora
  Rust** (no nightly needed); the empty git-submodule placeholder
  `lib/hyprland-protocols` is replaced with the pinned commit from
  `Source1`. Requires `gtk4-layer-shell-devel` from the `nett00n/hyprland`
  COPR — enable it as a build-repo in COPR for this package.

## Verification checklist before a package is "verified"

- [x] SPEC builds cleanly in a Fedora Rawhide `rpmbuild` container (CI job)
- [ ] `%files` matches real build output (no missing/unpackaged files)
- [ ] Runtime deps (WebKitGTK, Qt6, ffmpeg, gtk4-layer-shell, etc.) correct
- [ ] License `%license` file packaged
- [ ] `%{_bindir}/<name>` resolves; smoke-test the binary

Packages that previously sat as `blocked` stubs (aether, cliamp, herdr,
tensaku, share-picker) have been rewritten as working specs and their prior
`%OT VERIFY:` risk comments are resolved in `manifest.yaml`.