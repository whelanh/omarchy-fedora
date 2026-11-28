# COMPATIBILITY

Complete dependency/package status of Omarchy Quattro on Fedora.

Target: **Fedora Rawhide / recent stable, x86_64, systemd, Wayland.**

The authoritative source is `fedora/mappings/packages.yaml`; this document is a
human-readable summary. Classifications:

- `FEDORA_OFFICIAL` — in Fedora official repos
- `FEDORA_COPR` — via a COPR repository
- `FEDORA_RPMFUSION` — via RPM Fusion
- `FEDORA_FLATPAK` — best via Flathub
- `FEDORA_SUBSTITUTE` — same functionality, different package name
- `FEDORA_EXTERNAL` — via an upstream non-COPR RPM repo (e.g. mise)
- `FIRST_PARTY` — Omarchy first-party, shipped as RPMs from `whelanh/omarchy` COPR
- `NOT_AVAILABLE` — no reasonable Fedora equivalent
- `NOT_REQUIRED` — Arch-only tooling to drop

## Source of truth for the mapping

`fedora/scripts/lib/resolve.py --source <x>` prints the Fedora package names
for each classification. Static tests verify every upstream base package is
mapped.

## Summary counts (from packages.yaml, 259 entries)

| Classification | Count |
|---|---|
| fedora (official) | 127 |
| substitute | 38 |
| copr | 15 + 29 first-party |
| external (mise) | 1 |
| unavailable | 26 |
| drop (Arch-only) | 14 |
| rpmfusion | 7 |
| flatpak | 2 |

## Notable decisions (not mechanical renames)

### Hyprland ecosystem (COPR: `nett00n/hyprland`)
Fedora Rawhide ships `quickshell` (and `gtk4-layer-shell`) in official repos, but
**not `hyprland` itself** — the compositor is only available from COPR. The full
desktop ecosystem — `hyprland`, `hyprland-guiutils`, `hyprpicker`, `hyprsunset`,
`uwsm`, `xdg-desktop-portal-hyprland`, `gtk4-layer-shell` — comes from the
actively-maintained `nett00n/hyprland` COPR. `solopasha/hyprland` is no longer
actively maintained (as of 2026).

> Note: nett00n's `hyprland` is built against Fedora Rawhide's Lua 5.5 (Arch
> targets Lua 5.4). This can surface an upstream Hyprland-vs-Lua-5.5 config
> loading issue (`require` returning a boolean for some modules); see
> `fedora/rpm` docs and report against Hyprland upstream if it appears.

### NVIDIA (RPM Fusion nonfree)
Arch's `nvidia-*-dkms` + `nvidia-utils` map to Fedora's `akmod-nvidia` +
`xorg-x11-drv-nvidia` from RPM Fusion nonfree. Fedora uses `akmods`, not
`kernel-modules-hook`.

### FFmpeg: free build by default, either build satisfies the apps
Upstream's `ffmpeg` maps to Fedora's `ffmpeg-free` (`source: substitute`), and
the base manifest installs it. RPM Fusion's full `ffmpeg` **Conflicts** with
`ffmpeg-free` rather than obsoleting it, so a machine that already replaced the
free build (hardware encode, mpv, ...) used to fail the whole backfill on
`ffmpeg-free`, and the first-party RPMs that declared `Requires: ffmpeg-free`
could not be installed at all. Both fixes are now in place: the seven apps that
shell out to FFmpeg (cliamp, hype, monologue, omacut, omaview, owe,
superwhisper-bin) require `/usr/bin/ffmpeg` instead of the package, and
`omarchy_fedora_install_list` skips a manifest entry when its conflicting
replacement is installed. The free-vs-full choice stays the user's; the port
never forces either.

### Boot / kernel
Arch's custom kernels (`linux-ptl`, `linux-t2`) and `linux-headers` have no
direct analog: Fedora uses the stock `kernel` and `kernel-devel`. Limine and
mkinitcpio are replaced by Fedora's GRUB2/systemd-boot and dracut.

### mise (external RPM repo)
Arch's `mise-bin` maps to the Fedora binary `mise`, but mise is **not** in
Fedora official repos (a `packages.fedoraproject.org` lookup returns 404 for
both `mise` and `mise-bin`). Omarchy's `omarchy-default-agent` (shell menu →
"install an opening agent" like opencode/claude) and `omarchy-install-dev-env`
both drive everything through `mise use -g`, so it must be present. It ships
from the upstream mise RPM repo (`https://mise.jdx.dev/rpm/mise.repo`, signed,
gpgcheck=1) enabled by the installer via `dnf config-manager --add-repo`. See
`fedora/mappings/repositories.yaml` (entry `mise`).

### Default browser: Chromium instead of Google Chrome
Upstream made Google Chrome the default browser for new installs in
`b10da7e59` (Nov 2026): `google-chrome` replaced `chromium` in
`omarchy-base.packages`, and link handling, the dock, the web-app fallback and
`omarchy-provision-user`'s `xdg-settings set default-web-browser` all name
Chrome; Chromium became an optional browser in Install/Remove.

Fedora cannot follow that mechanically: Google Chrome is proprietary and
distributed only from Google's own RPM repository
(`https://dl.google.com/linux/chrome/rpm/stable/x86_64`, no official `.repo`
file — the definition is vendored as a baseurl). Enabling a proprietary
third-party repo for every install is a policy change this port has so far not
made for defaults (`rpmfusion` is opt-in via `--nvidia`). So:

- `google-chrome` maps `source: substitute` to Fedora's `chromium`, which
  `fedora/packages/base.txt` installs and which is the browser XDG resolves for
  `x-scheme-handler/http(s)` on an install without Chrome;
- the existing `chromium.desktop` / `chromium` compat shim in
  `fedora/scripts/install.sh` keeps Omarchy's `chromium.desktop`-based code
  paths working;
- real Chrome remains one click away: the Install menu
  (`fedora/mappings/menu-packages.conf`, row `google-chrome`) installs
  `google-chrome-stable` from Google's signed direct RPM, and a user who
  installs it gets Chrome as their browser (existing installs keep their
  browser upstream too).

If full parity is wanted later, the change is: add Google's repo to
`fedora/mappings/repositories.yaml` as `kind: external-repo` (needs a baseurl
definition, as Google ships no `.repo`), swap `chromium` for
`google-chrome-stable` in `base.txt`, and add a `google-chrome.desktop` stub
only for machines without Chrome.

### First-party Omarchy binaries (FIRST_PARTY, COPR `whelanh/omarchy`)
34 Omarchy packages (`aether`, `cliamp`, `disktree-bin`, `fantasi`,
`flowtunes`, `gliff`, `herdr`, `hype`, `hyprland-preview-share-picker`,
`monologue`, `omacalc`, `omacut`, `omapresent`, `omaview`, `omarchy-emacs`,
`omarchy-folio`, `omarchy-hyprland-titlebars`, `omarchy-local-ai`,
`omarchy-screensaver`, `omarchy-themes-intros`, `omarchy-themes-loops`,
`omawrite`, `omasnap`, `openai-codex-desktop`, `owe`, `owe-lockfeed`,
`omarchy-pi-coding-agent`, `plain`,
`qtengine`, `signed`, `superwhisper-bin`, `tobi-try → try`, `ttfx`,
`voxtype-bin`) are
source-built or repacked as Fedora RPMs. Specs live in `fedora/rpm/` (one SPEC
per package) with a `manifest.yaml` (repo, build system, license, status) and
publish tooling in `fedora/rpm/copr/`. 31 of them are installed by the default
first-party set; `omarchy-emacs`, `openai-codex-desktop` and `voxtype-bin` are
published for on-demand install from Omarchy's Install menu. Five former
packages are now **retired**: `elsewhen` (`status: retired`; upstream moved it
in-tree as `omarchy.elsewhen`), `openai-codex-bin` (upstream installs the Codex
CLI through mise, and `omarchy-upgrade-to-quattro` removes the old pacman
package), `tensaku` (upstream replaced the screenshot annotator with
`omasnap`), and `cards`/`checkmate` (upstream replaced both desktop games with
web pages inside Game Vibes).
The installer no longer installs any of them and `omarchy update` prunes them.
The `elsewhen` spec is kept only as a reference for the Fedora-native migration
that renames/dedups existing installs (`fedora/migrations/*-elsewhen-retire.sh`);
the `openai-codex-bin` and `tensaku` specs are removed, and
`fedora/rpm/copr/delete-retired.sh` drops their COPR copies.

Agent/toolchain CLIs (opencode, codex, claude, and the rest of Omarchy's
default agents) are **not** RPMs — upstream installs them through mise at user
setup (`install/user/mise.sh` → `omarchy-mise-install`), and the Fedora layer
does the same (`fedora/scripts/lib/mise.sh`).

**Status — 31 verified, 1 retired, 0 blocked.** Every verified package builds
cleanly in a Fedora Rawhide container and is published from the
`whelanh/omarchy` COPR. The default installer enables that COPR and installs
the 28-package default set (disable with `install.sh --no-firstparty`); the
three on-demand packages are installed from Omarchy's Install menu.

All 31 are now published: `omarchy-folio` (formerly `folio`, renamed because
Fedora owns that name) and `plain` landed in the COPR. The machinery that kept
installs working during the gap stays, because a future publish can lag a
release; while a first-party RPM is unpublished the port degrades instead of
breaking:

- `omarchy_fedora_install_firstparty` asks the enabled repos what actually
  exists (`dnf repoquery --available`) and installs the rest, warning about the
  ones still missing — a fresh install does not abort and an update keeps
  working, with the next run backfilling.
- a retired package is not pruned while its replacement is missing
  (`fedora/mappings/retired-replacements.conf`: nautilus until omarchy-folio is
  installed), so nobody is left without a file manager in the gap.
- a migration whose precondition is not met yet exits `75` (EX_TEMPFAIL) rather
  than failing: `omarchy update` reports it as **deferred**, writes no
  one-shot marker, and retries on the next update (see
  `fedora/migrations/README.md`).

### Omaview replaces imv and mpv (upstream 9599f7661)
Upstream made **Omaview** its picture viewer and media player, replacing `imv`
and `mpv` in `omarchy-base.packages`. It is packaged first-party (`omaview`,
Qt6/CMake, built from source) and is in the default set. `imv` and `mpv-mpris`
are retired: they are no longer installed and `omarchy update` prunes them,
with `retired-replacements.conf` keeping `imv` until `omaview` is actually
installed. `mpv` itself stays installed as a dependency of `owe`, which plays
video wallpapers through it (its packaged launcher stays hidden via
`launcher.hides`).

On Arch the associations come from the packaged
`/usr/share/applications/mimeapps.list`; on Fedora that path belongs to
`shared-mime-info`. The port therefore fills in the user's associations for
Omaview's MIME types only where no handler is set (fresh installs and updates),
and the `*-omaview-replaces-imv.sh` migration repoints entries that still name
`imv.desktop`/`mpv.desktop` and removes Omarchy's old launcher copies when they
are unmodified. `kimageformats` (HEIC, AVIF, JPEG XL) maps to a
`Recommends: kf6-kimageformats`, matching upstream's optdepends.

### Cards and Checkmate moved into Game Vibes (upstream 64c0b627c)
Upstream briefly added two of its own games to `omarchy-base.packages`: **Cards**
(Klondike solitaire, fad23cf81) and **Checkmate** (3D chess, 3489996a2), with
migrations that installed them on existing machines. Two days later 64c0b627c
("Add a Game starter that makes three.js games for the launcher", #16308)
replaced both desktop apps with single-file web pages in **Game Vibes**
(`default/games/vibes/{cards,checkmate}`, opened from the launcher entry `Game
Vibes` through `omarchy-games-vibes-launch`) and deleted those two lines from
the base list, so nothing installs the Qt apps by default any more.

The port retired the RPMs with them: `fedora/rpm/cards` and
`fedora/rpm/checkmate` are gone, along with their `packages.yaml` and
`manifest.yaml` entries, and both are listed in the two `retired-packages.conf`
files, so `omarchy update` prunes them from existing machines and
`delete-retired.sh` deletes the published copies from the COPR. The Game Vibes
games need no Fedora packaging: they ship in the vendored upstream tree and
open as `file://` web apps.

| Package | Version | Notes |
|---------|---------|-------|
| aether | v4.33.0 | Go/Wails, repacked release binary |
| cliamp | v2.4.1 | Go/CGO, repacked release binary |
| disktree-bin | v0.11.0 | Rust/GPUI disk-usage treemap; repacked release, Provides disktree |
| fantasi | v0.3.0 | Qt6/CMake local image model app |
| gliff | v0.4.3 | Hyprland remote desktop over SSH; Rust, crates vendored |
| flowtunes | v0.4.0 | Qt6/CMake local music app (GStreamer MP3 plugins) |
| omarchy-folio | v0.7.5 | Qt6/CMake file manager (Files); replaces Nautilus, and its Open/Save dialogs |
| omarchy-emacs | v1.10.1 | noarch Emacs theme/font integration; opt-in |
| omarchy-hyprland-titlebars | v0.4.0 | Hyprland plugin (hyprbars), built against nett00n/hyprland-devel |
| omarchy-local-ai | v0.18.0 | noarch local-model engine + recipe catalog |
| omarchy-screensaver | v1.3.1 | native Wayland screensaver (ttfx branding) |
| herdr | v0.9.5 | Rust, repacked release binary (herdrdev/herdr) |
| hype | v0.7.1 | Qt6/CMake Markdown presentation editor |
| hyprland-preview-share-picker | v0.3.1 | Rust/GTK4, source-built |
| monologue | v0.4.1 | Qt6/CMake webcam recorder + libpulse/turbojpeg |
| omapresent | v0.1.3 | Qt6 + QtWebEngine Markdown presentations (successor to hype) |
| omacalc | v0.4.2 | Qt6/CMake |
| omacut | v0.8.4 | Qt6/CMake + ffmpeg |
| omaview | v0.1.2 | Qt6/CMake picture viewer + media player (replaces imv/mpv) |
| omawrite | v0.7.8 | Qt6/CMake |
| omarchy-themes-intros | v2026.11.24.1 | noarch theme intro videos (built from the release tag) |
| omarchy-themes-loops | v2026.11.22 | noarch theme live background loops |
| omasnap | v1.26.3 | built from source (supersedes tensaku) |
| openai-codex-desktop | v26.1120.50957 | ChatGPT desktop .deb repack; on-demand, proprietary |
| owe | v0.2.19 | meson/C wallpaper engine (mpv + ffmpeg-free) |
| owe-lockfeed | v0.2.19 | Qt6 QML lock-screen feed module |
| omarchy-pi-coding-agent | v1.7.0 | Bun standalone binary, repacked from the upstream release |
| plain | v0.4.2 | Qt6/CMake text editor for config files |
| playwright-cli | v0.1.25 | Microsoft @playwright/cli; npm deps vendored, HELD on npm alpha pins |
| qtengine | v0.2.4 | Qt6 platform theme (replaces `gtk3`); AUR-only, first-party |
| signed | v0.3.2 | Qt6/CMake PDF signing app |
| superwhisper-bin | v1.3.1 | proprietary Superwhisper dictation; vendor Minisign repack |
| try (tobi-try) | v1.10.1 | Ruby gem |
| ttfx | v0.5.1 | pure Rust/cargo |
| voxtype-bin | v1.3.2 | Whisper/OSD dictation backend; opt-in |

Dropped from RPM scope (were in the original 13): `asdcontrol` (archived
upstream, Apple-display-only), `omarchy-nvim` (in-tree LazyVim cache
assembly), and `usage` (already shipped in-tree by the base install — an RPM
would file-conflict). Rationale in `fedora/rpm/README.md`.
`hyprland-preview-share-picker` needs `gtk4-layer-shell-devel`, which the
COPR pulls from the `nett00n/hyprland` build repo.

## Omarchy CLI / plugin commands on Fedora

The `omarchy` CLI (including `omarchy plugin add/enable/list/update`, `omarchy
theme`, `omarchy capture`, etc.) is **distro-neutral**: the `omarchy-*` scripts
depend only on `git`, `jq`, `gum`, `git-delta` (pager) and the live Quickshell
session — no package manager. The installer wires them onto PATH by symlinking
`bin/omarchy-*` → `/usr/bin/omarchy-*` and installing
`/etc/profile.d/omarchy.sh` (which sources the upstream env-bootstrap to set
`OMARCHY_PATH=/usr/share/omarchy`).

Caveats:
- `omarchy plugin enable/disable` talk to the running shell via
  `omarchy-shell shell enablePlugin`, so Quickshell must be running.
- The 31 first-party binary packages are built and published from the
  `whelanh/omarchy` COPR; the default installer installs the 28-package default
  set (`--no-firstparty` to skip) and `omarchy-emacs`, `openai-codex-desktop`
  and `voxtype-bin` install on demand from the menu. All are `verified` in
  `fedora/rpm/manifest.yaml`.
  (`elsewhen` is retired and no longer installed or published.)
- `gum` and `git-delta` were added to `fedora/packages/base.txt` as
  dependencies of the CLI layer.
- `omarchy update` converges on upstream, not just adds: packages listed in
  `fedora/mappings/retired-packages.conf` are never installed and are removed on
  update (dependency-aware — anything another installed package still requires
  is left in place with a warning). Set `OMARCHY_FEDORA_NO_PRUNE=1` to skip.
  Add a name there when upstream drops it from `omarchy-base.packages`.
- The SUPER+SPACE **Install** rows call `omarchy-pkg-add`/`-present` with
  Arch/AUR names. `fedora/mappings/menu-packages.conf` (read at runtime by
  `fedora/scripts/lib/pkg.sh`) translates those to Fedora package names, COPRs,
  vendor repos/direct RPMs, or Flathub, so the menu rows resolve on Fedora.
  Native sources are tried first with an automatic Flathub fallback (vendor and
  COPR packages generally target stable Fedora, so rawhide lands on Flatpak).
  When a Flatpak is installed, the shim best-effort applies the later native
  integration upstream expects: a `/usr/bin/<cmd>` launcher, a NoDisplay desktop
  id alias, and (for Chromium-family browsers) a `flatpak override` bind-mount
  of the host machine-policy dir so theme `color.json` applies. Unlisted names
  pass through to dnf unchanged; apps with no Fedora/Flathub source are marked
  `unavailable` and skipped with a warning instead of failing the script.

## Known incompatibilities / open work

1. **First-party RPM packaging (done)** — 26 Omarchy binaries built + published
   from the `whelanh/omarchy` COPR (`fedora/rpm/`, see `fedora/rpm/copr/`) plus
   one retired spec kept for migrations. Installed by the default installer. CI
   re-verifies the specs on push.
2. **libalpm hooks / "update guard"** — Arch's pacman PreTransaction guard that
   forces updates through `omarchy update` has no dnf equivalent; dropped.
3. **Firewall: firewalld, not UFW (not a live problem)** — upstream configures
   UFW (`upstream/install/config/firewall.sh`), but Fedora ships **firewalld
   active and enabled by default**, which already gives the same "deny incoming /
   allow outgoing" posture — so a fresh omarchy-fedora machine is firewalled with
   no action, which is why no firewall problem is observed. The Fedora layer does
   **not** run upstream's `firewall.sh`, and there is no firewall logic anywhere
   in `fedora/scripts/`. `ufw` is listed in `fedora/packages/base.txt` but is left
   unconfigured (`systemctl` reports it inactive/disabled), i.e. inert — and it
   must stay that way: enabling both firewalld and ufw is the foot-gun (note
   `/etc/ufw/ufw.conf` already reads `ENABLED=yes`, so guard against anything
   enabling the unit). Decision: standardize on `firewalld` (cf. the `ufw-docker`
   mapping note: "prefer firewalld + docker integration"). **Not yet done:**
   translating upstream's UFW *allowances* into firewalld services/ports —
   LocalSend `53317/udp` + `53317/tcp` and Docker's host-DNS allow — so those
   optional features stay blocked by the default zone until wired. Consider
   dropping the redundant `ufw` from base.
4. **PAM/authselect (not a live issue)** — the earlier "Phase 6" note described
   the wrong thing. Upstream has exactly one script that touches an
   authselect-owned file: `upstream/install/config/increase-lockout-limit.sh`
   `sed`s `/etc/pam.d/system-auth`, which on Fedora is a symlink into
   `/etc/authselect/` and would be reverted by `authselect apply-changes`. The
   Fedora installer **never runs it** — nor any other `install/config/*` or
   `install/login/*` script — so nothing authselect owns is edited. The PAM
   services that matter are instead wired the Fedora-native way: the lock
   screen's `/etc/pam.d/omarchy-lock-password` is created by
   `omarchy-apply-lock` (via `install_omarchy_lock_pam`) and carries
   `pam_faillock.so … deny=10 unlock_time=120`; fingerprint auth uses the
   authselect `with-fingerprint` feature (`/etc/authselect/system-auth` →
   `pam_fprintd.so`) plus our `install_omarchy_fingerprint_shim` (`fprintd-pam`),
   not a hand edit. Two residual gaps, both hardening/cosmetic: (a) system-wide
   lockout parity is not applied — there is no `pam_faillock` in the authselect
   `system-auth`/`password-auth` stacks, so `sudo`/`login`/`ssh` use the profile
   default; add it via an authselect **custom profile** (as omadora does), never a
   `sed`. (b) upstream's fingerprint/FIDO2 setup hand-writes `/etc/pam.d/polkit-1`,
   which on Fedora is normally absent (`/usr/lib/pam.d/polkit-1` is the vendor
   stack) and a hand-rolled one drops `pam_faillock` — the bug upstream's
   migration `1788256455` repaired. Our shim rewrites only the `pacman` usage, not
   those PAM writes, so enrolling fingerprint/FIDO2 could reproduce it; the shim
   should point that file at `include system-auth`. Guardrail: never run
   `increase-lockout-limit.sh` directly.
5. **snapper boot-menu sync** — upstream uses `limine-snapper-sync`; on Fedora
   this needs a GRUB snapper plugin. Not yet wired.
6. **Session/display manager** — SDDM is available on Fedora and used; the
   installer installs the wayland-session entry, the Omarchy greeter config, and
   preselects the Omarchy session for the installing user. On a **GNOME
   Workstation** base, GDM owns the `display-manager.service` alias, and on
   Fedora 44+ **KDE** the default is Plasma Login Manager
   (`plasmalogin.service`, forked from SDDM but fixed to Breeze with no QML
   theme support), so a plain `systemctl enable sddm` fails outright ("already
   exists and is a symlink to .../plasmalogin.service") and the Omarchy greeter
   never appears. The installer therefore disables GDM/LightDM/LXDM/XDM/PLM
   before force-enabling SDDM (`systemctl enable --force`, Fedora's documented
   DM-switch mechanism). The user keeps their GNOME/KDE session entries, but
   GDM's session memory is ignored; SDDM's `[Last]` record is what decides the
   default. An opt-in `omarchy-plus` SDDM theme variant (session chooser that
   keeps the Omarchy look) is available via `install.sh --with-session-chooser`
   for converted machines where locking the greeter to Omarchy-only is
   undesirable; see `fedora/sddm-omarchy-plus/README.md`.
7. **Local models: podman is base, the NVIDIA toolkit is not packaged** —
   `omarchy-local-ai` runs its models in rootless podman containers. Upstream
   made `podman` and `crun` base packages (`0c6dc2038`) so setting up the first
   model installs nothing; both map to Fedora's official packages and are in
   `fedora/packages/base.txt`, so `omarchy update` backfills them on existing
   machines. `nvidia-container-toolkit` — added to `omarchy-other.packages` for
   NVIDIA machines, because it writes the CDI spec that hands the GPU to those
   containers — is **unavailable**: neither Fedora nor RPM Fusion packages it and
   NVIDIA ships it only from its own repository. Upstream's on-demand fallback in
   `bin/omarchy-agent-local` runs `pkexec /usr/bin/pacman -S`, a path that does
   not exist here; with podman/crun in base the only thing it could still ask for
   is that toolkit, so an NVIDIA machine runs local models on CPU until the user
   installs it from NVIDIA's repo.

## Requirement: no security bypass

The port does **not** disable SELinux, systemd security, or the firewall to
work around incompatibilities. Any proposed bypass is rejected.
