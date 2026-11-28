# omarchy-plus — opt-in SDDM greeter with a session chooser

> **The default login screen is greetd now.** Upstream 1795834060 replaced SDDM
> with greetd's Quickshell login screen, which this repo ports. The chooser is
> the opt-in alternative: `install.sh --with-session-chooser` (or
> `fedora/scripts/enable-session-chooser.sh` on an existing install) switches
> the display manager back to SDDM and selects this theme;
> `--without-session-chooser` returns to greetd.

Stock upstream Omarchy (`upstream/default/sddm/omarchy/Main.qml`) is deliberately
minimal: logo, lock icon, password box. It reads the username from
`/var/lib/sddm/state.conf` and logs into `sessionModel.lastIndex` (its uwsm
scan reads `Qt.DisplayRole`, which SDDM 0.21 does not implement, so it always
falls back). There is no on-screen way to pick a session or a different user —
on a machine converted from Fedora KDE/Sway/GNOME that is a one-way door back
into Omarchy only.

This prototype is the compromise, inspired by
https://github.com/xpusostomos/sddm-omarchy-plus (which is **not** vendored
here; `fedora/sddm-omarchy-plus/Main.qml` is reimplemented in this repo so it
is owned, reviewable, and tracks the stock theme):

- Installs **alongside** stock as `/usr/share/sddm/themes/omarchy-plus/`.
  Stock `omarchy` is never modified.
- Artwork (`logo.png`, `lock.png`, `entry.png`, `bullet.png` + `-failed`
  variants) is **symlinked** from the stock theme, so `omarchy-plymouth-set`
  theme recolors keep applying.
- A single drop-in `/etc/sddm.conf.d/zz-omarchy-plus.conf` sets
  `[Theme] Current=omarchy-plus`. The `zz-` prefix sorts after upstream's
  `10-theme.conf` / `99-omarchy-login.conf` (lexical order, later wins).
- Revert = delete that one file (or re-run the installer without the flag);
  SDDM falls back to stock `omarchy`.

## What it adds over stock

- **Session ComboBox** listing every session SDDM knows about (uses the
  `name` role; initial index genuinely prefers uwsm via `Qt.UserRole + 4`,
  fixing the stock DisplayRole scan). SDDM's `RememberLastSession` persists
  the choice.
- **Editable username field** prefilled with `userModel.lastUser`.
- Status line (login-failed vs. chooser-enabled hint).

Deliberately **not** in the prototype (present in the reference project, left
for later if users want it): power actions, clock, caps-lock warning, keyboard
layout selector, autorotate hook.

## Departure from "pure" Omarchy

This is Fedora-side UX, not upstream. Pure installs keep the stock greeter.
Use this when the machine is shared/converted and losing the KDE/Sway session
choice is worse than diverging from upstream login aesthetics.

## Usage

```bash
# Enable (installs theme + drop-in, keeps stock untouched):
sudo ./fedora/scripts/install.sh --with-session-chooser

# Revert to pure stock Omarchy greeter:
sudo ./fedora/scripts/install.sh
# (without the flag the zz- drop-in is removed; the omarchy-plus dir stays
# harmlessly in place for re-enabling)

# Update mode re-asserts whichever state was last installed (marker in
# /var/lib/omarchy-fedora/session-chooser):
sudo ./fedora/scripts/install.sh --update
omarchy update
```

### Migrating an install that predates the flag

`install.sh --with-session-chooser` only helps when you (re)run the installer.
An install made before the flag existed has the stock greeter, so the session
choice is unreachable. Opt in with the one-time migration instead:

```bash
sudo ./fedora/scripts/enable-session-chooser.sh
```

It publishes this canonical theme (replacing any hand-installed copy, e.g. the
upstream reference project's `make install`, which is not the version tested
here), selects it with the `zz-` drop-in, sets the marker update mode reads, and
**disables SDDM autologin** — a leftover `[Autologin]` block in `/etc/sddm.conf`
or `/etc/sddm.conf.d/autologin.conf`. Autologin bypasses the greeter entirely,
so the chooser can never appear at boot while it is on; the port seeds
`/var/lib/sddm/state.conf` instead (Omarchy stays preselected). It backs up the
old `/etc/sddm.conf` as `/etc/sddm.conf.omarchy-session-chooser.bak`. This is
deliberately **not** a `fedora/migrations/` entry: those run automatically on
every `omarchy update`, and opting in is a user decision.

Preview without installing (needs SDDM test mode, installs nothing):

```bash
sddm-greeter --test-mode --theme /usr/share/sddm/themes/omarchy-plus
```

## Maintenance contract

- `fedora/tests/static.sh` guards: flag parsing, theme install helper +
  call, zz drop-in ordering, artwork symlinks (not copies), UserRole + 4
  session lookup, revert path, and the opt-in `enable-session-chooser.sh`
  migration (canonical theme + marker + autologin disable; not auto-run).
- When upstream changes `default/sddm/omarchy/Main.qml` (logo/layout), mirror
  the visual parts here; the `upstream-sync` diff is the signal.
- `omarchy-refresh-sddm` rewrites `themes/omarchy`, not `themes/omarchy-plus`,
  so this survives refreshes — but the `#1a1b26` background literal must be
  updated by hand to track desktop theme changes, same as the reference.
