# whelanh/omarchy COPR publishing

This directory holds the tooling that publishes the 10 first-party Omarchy
RPMs (specs in `fedora/rpm/<pkg>/`) to the **`whelanh/omarchy`** COPR, so a
stock Fedora install gets them with a plain `dnf install` — no local builds.

## The 10 packages

aether, cliamp, herdr, hyprland-preview-share-picker, omacalc, omacut,
omawrite, tensaku, try (tobi-try), ttfx. All are `status: verified` in
`fedora/rpm/manifest.yaml` and built green end-to-end on `fedora:rawhide`
via `fedora/rpm/build-rpm-in-ci.sh`.

## Prereqs (run once, on the maintainer machine)

```sh
sudo dnf install -y copr-cli rpm-build python3-pyyaml cargo
```

`cargo` is required because the Rust packages (`ttfx`,
`hyprland-preview-share-picker`) vendor their crates.io dependencies at SRPM
time (see `fedora/rpm/vendor-rust.sh`) so COPR can build them offline.

Create an API token at **https://copr.fedorainfracloud.org/api/** (Scope:
`Create and build projects`). Then:

```sh
copr-cli login            # paste the JSON token into ~/.config/copr
```

The token authenticates all `copr-cli` calls below.

## 1. Create the project

```sh
bash fedora/rpm/copr/create-project.sh
```

This creates `whelanh/omarchy` with:
- chroot **fedora-rawhide-x86_64** (matches the container/CI verify target)
- build-time additional repo **nett00n/hyprland** — required because
  `hyprland-preview-share-picker` (and `tensaku`, runtime) need
  `gtk4-layer-shell-devel`, which official Fedora doesn't ship.

To review the settings afterwards: `copr-cli list` (or `create-project.sh
--check`).

> If a new Fedora release becomes the Omarchy target, add its chroot with
> `copr-cli modify whelanh/omarchy --chroot fedora-<N>-x86_64` and rebuild.

## 2. Build + submit

```sh
# build SRPMs locally, push to COPR (remote-build each in its chroot)
bash fedora/rpm/copr/submit-builds.sh

# a subset:
bash fedora/rpm/copr/submit-builds.sh aether ttfx

# just produce SRPMs (in ~/rpmbuild-omarchy/SRPMS), don't submit:
bash fedora/rpm/copr/submit-builds.sh --srpms-only
```

Watch: `copr-cli list-watch --output-format text` (unit status Succeeded /
Failed). A failed build shows the exact mock error via:
`copr-cli get-build <id>`.

## 3. Consumers

Enabling + installing on any Fedora box (what `fedora/scripts/install.sh`
already does when `--with-firstparty` is on, default):

```sh
sudo dnf copr enable whelanh/omarchy
sudo dnf install aether cliamp herdr hyprland-preview-share-picker \
                 omacalc omacut omawrite tensaku try ttfx
```

`fedora/scripts/lib/deps.sh` exposes
`omarchy_fedora_install_firstparty()` which resolves the exact set from
`fedora/mappings/packages.yaml` (`source: copr`).

## Rebuild / update policy

- **New upstream version**: bump `Version:` + add a `%changelog` entry in the
  package's spec, re-run `submit-builds.sh <pkg>`.
- **Root-cause fix**: fix the spec in `fedora/rpm/`, container-verify with
  `fedora/rpm/build-rpm-in-ci.sh <pkg>`, then bump `Release:` and resubmit.
- **Full refresh**: `bash fedora/rpm/copr/submit-builds.sh` after any spec,
  manifest, or mapping change. CI (`fedora-build.yml`) re-verifies the specs,
  then the COPR build is the release step.

## Checking for upstream updates

```sh
bash fedora/rpm/copr/check-updates.sh
```

Queries each package's upstream GitHub repo (releases + tags, pre-releases
filtered) and reports any whose version is newer than the packaged one, e.g.
`cliamp 1.63.2 -> v2.0.0 OUTDATED`. Exit status is 1 when something is stale.
Uses unauthenticated GitHub API (~2 calls/package, well under rate limits).

## Why COPR and not official Fedora

Fedora source rules require vendored Rust/Go deps and a maintainer review
process; several of these upstreams ship only Arch/static binaries. COPR
keeps the build transparent (from these repo SPECs), signs with the COPR GPG
key, and is fully scriptable from this repo.

## Security / trust notes

- Every repack (aether, cliamp, herdr, tensaku) installs the byte-for-byte
  upstream release binary; the spec pins the exact version + Source URLs.
- `hyprland-preview-share-picker` is compiled from source on the versioned
  tag with hyprland-protocols vendored at a pinned commit.
- Qt trio + ttfx + try build from their upstream tags in the REMOTE COPR
  build (not locally) — same spec, reproducible result.
- COPR runs builds on Fedora's infrastructure with chroots; rebuilt RPMs are
  signed and `dnf copr enable` enforces gpgcheck.