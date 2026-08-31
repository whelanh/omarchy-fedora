# Omarchy Quattro first-party RPMs (scaffold)

This directory scaffolds Fedora RPM packaging for the 13 "first-party" command
binaries that Omarchy ships but that are **not** available (or not maintained)
in Fedora official/COPR repos. They are currently marked `source: build` in
`fedora/mappings/packages.yaml` and were surfaced as remaining work in
`COMPATIBILITY.md`.

> **Status: SCAFFOLD — PENDING-VERIFY.** Most spec files are drafted from the
> upstream `omacom/omarchy-pkgs` PKGBUILDs and the projects' own build
> instructions, but none have been built in a Fedora `mock`/`rpmbuild` chroot
> yet. Treat every spec as a starting point; verify by actually building before
> shipping. Each package carries a `%OT VERIFY:` comment noting its specific
> risk.

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
| omacalc | omacom/omacalc | Qt6 / qmake6 | MIT | ready |
| omacut | omacom/omacut | Qt6 / qmake6 | MIT | ready |
| omarchy-nvim | omacom/omarchy-pkgs | config + LazyVim cache | MIT | ready |
| omawrite | omacom/omawrite | Qt6 / qmake6 | MIT | ready |
| tensaku | jondkinney/tensaku | Rust / GTK4 | MPL-2.0 | blocked |
| tobi-try | tobi/try | Ruby gem | MIT | ready (gem) |
| ttfx | omacom/ttfx | Rust / cargo | MIT | ready |
| usage | omacom/omarchy (in-tree) | Python | MIT | ready (config) |

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

The four Qt6 apps (omacalc, omacut, omawrite) and ttfx (pure Rust) are the
easiest first builds; omarchy-nvim and usage are config/meta packages.

## Verification checklist before a package is "ready"

- [ ] SPEC builds cleanly in `mock -r fedora-rawhide-x86_64`
- [ ] `%files` matches real build output (no missing/unpackaged files)
- [ ] Runtime deps (WebKitGTK, Qt6, ffmpeg, gtk4-layer-shell, etc.) correct
- [ ] License `%license` file packaged
- [ ] Symlinked `/usr/bin/<name>` resolves; smoke-test the binary
