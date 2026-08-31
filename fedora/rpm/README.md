# Omarchy Quattro first-party RPMs (scaffold)

This directory scaffolds Fedora RPM packaging for the 13 "first-party" command
binaries that Omarchy ships but that are **not** available (or not maintained)
in Fedora official/COPR repos. They are currently marked `source: build` in
`fedora/mappings/packages.yaml` and were surfaced as remaining work in
`COMPATIBILITY.md`.

> **Status: 5 VERIFIED, 8 BLOCKED.** The five single-binary packages
> (omacalc, omacut, omawrite, ttfx, try) have been **built successfully in a
> Fedora Rawhide container** (`manifest.yaml` status `verified`) and are
> auto-built by CI. The remaining eight are `blocked` (need extra toolchain,
> prebuilt-repack, or in-tree source assembly) and carry a `%OT VERIFY:`
> comment noting the specific risk. Treat a `blocked` spec as a starting point;
> verify by actually building before shipping.

## Layout

- `manifest.yaml` — machine-readable record of every package: repo, language,
  build command, license, upstream reference, and verification status.
- `build-rpm.sh <pkg>` — helper that runs `rpmbuild`/`mock` for one package.
- `<pkg>/<pkg>.spec` — one SPEC per package.

## How to build

Prereqs (Fedora):

```sh
sudo dnf install -y rpm-build rpmdevtools mock
```

Build one package (from the repo root):

```sh
bash fedora/rpm/build-rpm.sh omacalc
```

Or all of them (those with `status: ready`):

```sh
bash fedora/rpm/build-rpm.sh --all
```

Packages flagged `status: blocked` (bad toolchain/nightly Zig/archived) in
`manifest.yaml` are skipped until real verification unblocks them.

## The 13 packages

| Package | Repo | Lang/build | License | Status |
|---------|------|-----------|---------|--------|
| aether | omacom/aether | Go + Wails (prebuilt release) | MIT | blocked |
| asdcontrol | nikosdion/asdcontrol | C++ / make | GPL-2.0 | blocked |
| cliamp | bjarneo/cliamp | Go / CGO | MIT | blocked |
| herdr | omacom-io/herdr (fork) | Rust / pinned Zig 0.15 | Apache-2.0 | blocked |
| hyprland-preview-share-picker | WhySoBad/... | Rust / nightly | MIT | blocked |
| omacalc | omacom/omacalc | Qt6 / qmake6 | MIT | verified |
| omacut | omacom/omacut | Qt6 / qmake6 | MIT | verified |
| omarchy-nvim | omacom/omarchy-pkgs | config + LazyVim cache | MIT | blocked |
| omawrite | omacom/omawrite | Qt6 / qmake6 | MIT | verified |
| tensaku | jondkinney/tensaku | Rust / GTK4 | MPL-2.0 | blocked |
| tobi-try | tobi/try | Ruby gem | MIT | verified |
| ttfx | omacom/ttfx | Rust / cargo | MIT | verified |
| usage | omacom/omarchy (in-tree) | Python | MIT | blocked |

## Why some are "blocked"

Feasibility was researched in `fedora/rpm/manifest.yaml`. Several need a
non-trivial toolchain that Fedora doesn't ship cleanly:

- **aether** — best matched by vendoring the upstream prebuilt release binary
  (which is exactly what Omarchy's own Arch PKGBUILD does) rather than
  compiling the Wails toolchain; needs a binary-repackaging spec + WebKitGTK.
- **herdr** — requires a **pinned Zig 0.15 toolchain** (`cargo build --frozen
  --release` with Zig linker) not packaged in Fedora; vendor the Zig fetch or
  use a prebuilt.
- **hyprland-preview-share-picker** — requires **nightly Rust** + vendored
  `hyprland-protocols` submodule; needs a rust-toolchain wrapper in mock.
- **tensaku** — GTK4/libadwaita/relm4 with `gtk4-layer-shell`; verify libdevel
  availability.
- **asdcontrol** — archived (Aug 2025), Apple-display-specific; likely dropped
  for most hardware.
- **cliamp** — Go/CGO with ALSA audio deps; verify libdevel names.
- **omarchy-nvim** — assembles a ~116 MiB LazyVim cache via headless `nvim`
  sync; the source is an in-tree config assembly, not a standalone repo.
- **usage** — source lives in the omarchy monorepo; needs a bundled source
  tarball before it can be a standalone RPM.

The five **verified** packages (omacalc, omacut, omawrite, ttfx, try) are
built in CI. The rest need toolchain/assembly work before they'll build.

## Verification checklist before a package is "verified"

- [x] SPEC builds cleanly in a Fedora Rawhide `rpmbuild` container (CI job)
- [ ] `%files` matches real build output (no missing/unpackaged files)
- [ ] Runtime deps (WebKitGTK, Qt6, ffmpeg, gtk4-layer-shell, etc.) correct
- [ ] License `%license` file packaged
- [ ] Symlinked `/usr/bin/<name>` resolves; smoke-test the binary
