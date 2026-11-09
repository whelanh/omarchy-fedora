# whelanh/omarchy COPR publishing

This directory holds the tooling that publishes the 24 first-party Omarchy
RPMs (specs in `fedora/rpm/<pkg>/`) to the **`whelanh/omarchy`** COPR, so a
stock Fedora install gets them with a plain `dnf install` — no local builds.

## The 24 packages

aether, cliamp, disktree-bin, gliff, herdr, hype,
hyprland-preview-share-picker, monologue, omacalc, omacut, omapresent,
omarchy-emacs, omarchy-hyprland-titlebars, omawrite, omasnap,
openai-codex-desktop, owe, owe-lockfeed, signed, superwhisper-bin,
try (tobi-try), ttfx, voxtype-bin. All are `status: verified` in
`fedora/rpm/manifest.yaml` and built green end-to-end on `fedora:rawhide`
via `fedora/rpm/build-rpm-in-ci.sh`. (`elsewhen` and `openai-codex-bin` are
`status: retired`: upstream moved Elsewhen in-tree as `omarchy.elsewhen`, and
installs the Codex CLI through mise rather than pacman, so neither is built or
published; their specs are kept only for the migrations that clean existing
machines. `tensaku` is retired too: upstream replaced it with `omasnap`, so its
spec and manifest entry are gone and `delete-retired.sh` drops the COPR copy.)

> `omapresent` is the successor to `hype`; upstream still lists `hype` in
> `omarchy-base.packages`, so both are published for now.

> `omarchy-emacs`, `voxtype-bin` and `openai-codex-desktop`
> are published in the COPR but installed **on demand** (from the SUPER+SPACE
> Install menu), not by the default first-party set.

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
bash fedora/rpm/copr/create-project.sh                        # rawhide only
bash fedora/rpm/copr/create-project.sh fedora-45-x86_64       # rawhide + Fedora 45
```

This creates `whelanh/omarchy` with:
- chroot **fedora-rawhide-x86_64** (matches the container/CI verify target),
  plus any extra chroots passed as args (rawhide is always kept enabled)
- a **per-chroot** build-time additional repo **nett00n/hyprland** (one
  release-matched URL per chroot) — required because
  `hyprland-preview-share-picker` needs `gtk4-layer-shell-devel`, which
  official Fedora doesn't ship. It is wired per-chroot, not project-wide, so a
  Fedora 45 build never sees a rawhide hyprland repo.

To review the settings afterwards: `copr-cli get whelanh/omarchy` and
`copr-cli get-chroot whelanh/omarchy/<chroot>` (or `create-project.sh --check`).

> **Adding a Fedora release later** (e.g. Fedora 45): add its chroot *and* its
> build repo, then rebuild. `copr-cli modify --chroot` **replaces** the chroot
> list, so always list every chroot you want:
>
> ```sh
> copr-cli modify whelanh/omarchy \
>   --chroot fedora-rawhide-x86_64 --chroot fedora-45-x86_64
> copr-cli edit-chroot whelanh/omarchy/fedora-45-x86_64 \
>   --repos https://download.copr.fedorainfracloud.org/results/nett00n/hyprland/fedora-45-x86_64/
> bash fedora/rpm/copr/submit-builds.sh
> ```

## 2. Build + submit

```sh
# build SRPMs locally, push to COPR (remote-build in every enabled chroot)
bash fedora/rpm/copr/submit-builds.sh

# a subset:
bash fedora/rpm/copr/submit-builds.sh aether ttfx

# only a specific chroot (e.g. a newly added release):
bash fedora/rpm/copr/submit-builds.sh --chroot fedora-45-x86_64

# just produce SRPMs (in ~/rpmbuild-omarchy/SRPMS), don't submit:
bash fedora/rpm/copr/submit-builds.sh --srpms-only

# submit and return immediately, without watching (pre-self-heal behaviour):
bash fedora/rpm/copr/submit-builds.sh --no-watch

# tune the retry budget (also settable via COPR_RETRIES / COPR_RETRY_DELAY):
bash fedora/rpm/copr/submit-builds.sh --retries 3 --retry-delay 120
```

The script submits one SRPM per `copr-cli build` call, watches the resulting
builds, and **self-heals transient failures**: if a chroot fails for a
recognisable infrastructure reason, only that chroot is resubmitted. The case
this exists for is the per-chroot `nett00n/hyprland` build repo briefly 404ing
while COPR's Pulp mirror resyncs — mock dies before `rpmbuild` with
`Failed to download metadata` / `Usable URL not found` / a `repomd.xml` 404.
Retries are bounded (`COPR_RETRIES`, default 2) with a linear backoff
(`COPR_RETRY_DELAY`, default 60s). Compile errors and unresolved
`BuildRequires` do not match the transient pattern: they are reported and never
retried.

Manual inspection: `copr-cli status <id>` for per-chroot state and mock errors,
`copr-cli watch-build <id>...` to follow a build, or the web page
`https://copr.fedorainfracloud.org/coprs/whelanh/omarchy/build/<id>/`. Failed
logs are published at
`https://download.copr.fedorainfracloud.org/results/whelanh/omarchy/<chroot>/<id>-<pkg>/builder-live.log.gz`.

## 3. Consumers

Enabling + installing on any Fedora box (what `fedora/scripts/install.sh`
already does by default; `--no-firstparty` skips it):

```sh
sudo dnf copr enable whelanh/omarchy
sudo dnf install aether cliamp disktree-bin gliff herdr hype \
                 hyprland-preview-share-picker monologue omacalc omacut \
                 omapresent omarchy-hyprland-titlebars omawrite omasnap owe \
                 owe-lockfeed signed superwhisper-bin try ttfx
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
- **`omarchy-hyprland-titlebars`**: a Hyprland plugin compiled against a specific
  Hyprland build (upstream marks `rebuild_on: hyprland`). It is built against
  `hyprland-devel` from the `nett00n/hyprland` per-chroot repo, so it must be
  rebuilt (bump `Release:` and resubmit) whenever that repo's Hyprland moves.
  `check-updates.sh --rebuilds` compares the latest successful COPR builds and
  flags stale dependents; `auto-update.sh` bumps `Release:` and resubmits them
  automatically (skip with `--no-rebuilds`).

## Retiring / removing a package

Deleting `fedora/rpm/<pkg>/` and its `manifest.yaml` entry stops **new** builds
— `auto-update.sh`, `check-updates.sh` and `submit-builds.sh` only touch
`status: verified` packages — but the COPR keeps the source package and its
build history, so `dnf copr enable` users still see the old package. Remove it
from the project with:

```sh
bash fedora/rpm/copr/delete-retired.sh --dry-run   # show what would be deleted
bash fedora/rpm/copr/delete-retired.sh             # delete them
```

It deletes every SRPM Name listed in `fedora/rpm/copr/retired-packages.conf`
(currently `elsewhen` and `openai-codex-bin`, both retired: Elsewhen moved
in-tree as `omarchy.elsewhen`, and the Codex CLI is installed through mise).
The script is idempotent, so re-running it is harmless. `auto-update.sh
--prune-retired` runs it automatically (best-effort) as part of the update, so a
cron job / systemd timer keeps the COPR clean:

```sh
bash fedora/rpm/copr/auto-update.sh --yes --prune-retired
```

## Checking for upstream updates

```sh
bash fedora/rpm/copr/check-updates.sh
```

Queries each package's upstream GitHub repo (releases + tags, pre-releases
filtered) and reports any whose version is newer than the packaged one, e.g.
`cliamp 1.63.2 -> v2.0.0 OUTDATED`. Exit status is 1 when something is stale.
Uses unauthenticated GitHub API (~2 calls/package, well under rate limits).

Some specs (`superwhisper-bin`, `openai-codex-desktop`) pin auxiliary files —
launcher, service, desktop entries, release key, setup scripts — to a specific
`omacom/omarchy-pkgs` commit. Those files can change on their own, without the
app version moving, so the pin goes stale silently:

```sh
bash fedora/rpm/copr/check-updates.sh --pins
```

It compares each pinned file against `omarchy-pkgs` master and reports
`OUTDATED` / `REMOVED upstream`. When one changes, review the upstream diff,
update the commit SHA in the spec's `Source` URL, bump `Release:` + add a
`%changelog` entry, and resubmit that package.

Other checks:

```sh
bash fedora/rpm/copr/check-updates.sh --packages   # upstream <-> mapping drift
```

### Fully automated: check → bump → submit

```sh
# preview the bumps, change nothing
bash fedora/rpm/copr/auto-update.sh --dry-run

# bump spec Version/Release + %changelog and manifest.yaml, then submit
bash fedora/rpm/copr/auto-update.sh --yes

# bump + build SRPMs locally, don't submit
bash fedora/rpm/copr/auto-update.sh --yes --srpms-only

# also delete retired packages from the COPR (see "Retiring / removing")
bash fedora/rpm/copr/auto-update.sh --yes --prune-retired

# submit without watching/retrying the COPR builds
bash fedora/rpm/copr/auto-update.sh --yes --no-watch
```

`auto-update.sh` automates the manual loop above. It considers only
`status: verified` packages, bumps packages that share an upstream repo
(`owe` + `owe-lockfeed`) together to the same version, reads the current
version from the spec (so a stale manifest can't hide a bump), and writes all
edits only after every edit has succeeded. `--verify` additionally runs
`build-rpm-in-ci.sh` before submitting, and `--chroot <name>` (repeatable)
submits to specific chroots. The submit step watches the builds and retries
transient chroot failures as described in [Build + submit](#2-build--submit);
`--no-watch` restores fire-and-forget. `--prune-retired` runs
`delete-retired.sh` (best-effort) so retired packages are pulled from the COPR
too; it is skipped with `--srpms-only` and previewed with `--dry-run`. Set
`GITHUB_TOKEN`/`GH_TOKEN` (or use `gh auth token`) to avoid the
60-requests/hour unauthenticated API limit.

## Why COPR and not official Fedora

Fedora source rules require vendored Rust/Go deps and a maintainer review
process; several of these upstreams ship only Arch/static binaries. COPR
keeps the build transparent (from these repo SPECs), signs with the COPR GPG
key, and is fully scriptable from this repo.

## Security / trust notes

- Every repack (aether, cliamp, disktree-bin, herdr, omasnap, superwhisper-bin)
  installs the byte-for-byte upstream release binary; the spec pins the
  exact version + Source URLs. `superwhisper-bin` additionally verifies the
  vendor's Minisign signature before extraction.
- `hyprland-preview-share-picker` is compiled from source on the versioned
  tag with hyprland-protocols vendored at a pinned commit.
- Qt trio + ttfx + try build from their upstream tags in the REMOTE COPR
  build (not locally) — same spec, reproducible result.
- COPR runs builds on Fedora's infrastructure with chroots; rebuilt RPMs are
  signed and `dnf copr enable` enforces gpgcheck.