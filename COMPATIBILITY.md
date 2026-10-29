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

## Summary counts (from packages.yaml, 234 entries)

| Classification | ~Count |
|---|---|
| fedora (official) | ~120 |
| substitute | ~30 |
| copr | ~11 + 25 first-party |
| external (mise) | 1 |
| unavailable | ~19 |
| drop (Arch-only) | ~8 |
| rpmfusion | ~8 |
| flatpak | 1 |

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

### First-party Omarchy binaries (FIRST_PARTY, COPR `whelanh/omarchy`)
24 Omarchy packages (`aether`, `cliamp`, `disktree-bin`, `gliff`,
`herdr`, `hype`, `hyprland-preview-share-picker`, `monologue`, `omacalc`,
`omacut`, `omapresent`, `omarchy-emacs`, `omarchy-hyprland-titlebars`,
`omawrite`, `omasnap`, `openai-codex-desktop`, `owe`,
`owe-lockfeed`, `signed`, `superwhisper-bin`, `tensaku`, `tobi-try → try`,
`ttfx`, `voxtype-bin`) are
source-built or repacked as Fedora RPMs. Specs live in `fedora/rpm/` (one SPEC
per package) with a `manifest.yaml` (repo, build system, license, status) and
publish tooling in `fedora/rpm/copr/`. Two former packages are now **retired**
(`status: retired`): `elsewhen` (upstream moved it in-tree as
`omarchy.elsewhen`) and `openai-codex-bin` (upstream installs the Codex CLI
through mise, and `omarchy-upgrade-to-quattro` removes the old pacman package).
The installer no longer installs either and `omarchy update` prunes them. The
`elsewhen` spec is kept only as a reference for the Fedora-native migration
that renames/dedups existing installs (`fedora/migrations/*-elsewhen-retire.sh`).

Agent/toolchain CLIs (opencode, codex, claude, and the rest of Omarchy's
default agents) are **not** RPMs — upstream installs them through mise at user
setup (`install/user/mise.sh` → `omarchy-mise-install`), and the Fedora layer
does the same (`fedora/scripts/lib/mise.sh`).

**Status — 25 verified, 2 retired, 0 blocked.** Every verified package builds
cleanly in a Fedora Rawhide container and is published from the
`whelanh/omarchy` COPR. The default installer enables that COPR and installs
the set (disable with `install.sh --no-firstparty`).

| Package | Version | Notes |
|---------|---------|-------|
| aether | v4.30.0 | Go/Wails, repacked release binary |
| cliamp  | v2.2.0 | Go/CGO, repacked release binary |
| herdr   | v0.9.1 | Rust, repacked release binary (herdrdev/herdr) |
| hype    | v0.4.3 | Qt6/qmake6 Markdown presentation editor |
| hyprland-preview-share-picker | v0.2.1 | Rust/GTK4, source-built |
| monologue | v0.3.0 | Qt6/qmake6 webcam recorder + libpulse |
| omacalc | v0.2.2 | Qt6/qmake6 |
| omacut  | v0.4.0 | Qt6/qmake6 + ffmpeg |
| omawrite| v0.5.0 | Qt6/qmake6 |
| omasnap | v1.21.0 | repacked Arch release (supersedes tensaku) |
| owe     | v0.2.7 | meson/C wallpaper engine (mpv + ffmpeg-free) |
| owe-lockfeed | v0.2.7 | Qt6 QML lock-screen feed module |
| tensaku | v0.29.0 | repacked release tarball (GTK4) |
| try (tobi-try) | v1.10.1 | Ruby gem |
| ttfx    | v0.3.3 | pure Rust/cargo |

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
- The 25 first-party binary packages are built and published from the
  `whelanh/omarchy` COPR and installed by the default installer
  (`--no-firstparty` to skip); all are `verified` in `fedora/rpm/manifest.yaml`.
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

1. **First-party RPM packaging (done)** — 24 Omarchy binaries built + published
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

## Requirement: no security bypass

The port does **not** disable SELinux, systemd security, or the firewall to
work around incompatibilities. Any proposed bypass is rejected.
