#!/bin/bash
#
# Omarchy Quattro for Fedora - opt-in session chooser migration
#
# Installs written before install.sh --with-session-chooser existed have the
# stock Omarchy greeter: logo, lock icon, password box, no session picker. On a
# machine converted from Fedora KDE/Sway/GNOME that is a one-way door back into
# Omarchy. This one-time helper opts an EXISTING install into the omarchy-plus
# greeter (session + username choice) -- the Fedora-native equivalent of running
# `install.sh --with-session-chooser` on a fresh install.
#
# Deliberately NOT in fedora/migrations/: those run automatically on every
# `omarchy update`, and opting in is a user decision (it also stops the machine
# logging in by itself). Run it once, by hand:
#
#   sudo ./fedora/scripts/enable-session-chooser.sh
#
# What it does:
#   1. Publishes the canonical omarchy-plus theme from THIS checkout, replacing
#      any hand-installed copy (e.g. the upstream reference project's `make
#      install`, which writes a different Main.qml), so the greeter is the
#      version this repo tests.
#   2. Selects it with /etc/sddm.conf.d/zz-omarchy-plus.conf and records the
#      /var/lib/omarchy-fedora/session-chooser marker, so `omarchy update`
#      re-asserts the choice (install.sh update mode reads the marker).
#   3. Disables SDDM autologin: a leftover [Autologin] block in /etc/sddm.conf
#      and/or an upstream-style /etc/sddm.conf.d/autologin.conf. Autologin
#      bypasses the greeter entirely, so the chooser is unreachable at boot
#      while it is on. The Fedora port seeds /var/lib/sddm/state.conf instead
#      (install.sh configure_sddm_login), so removing autologin matches a fresh
#      --with-session-chooser install, where the greeter still preselects Omarchy.
#
# Idempotent. Takes effect at the next login (or reboot); it never restarts
# SDDM, which would kill the running session.
#
# Revert: `sudo ./fedora/scripts/install.sh` (drops the zz- drop-in), and
# restore the ${sddm_conf}.omarchy-session-chooser.bak this leaves behind to
# re-enable autologin.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

log()  { printf '\033[1;34m[omarchy-session-chooser] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[omarchy-session-chooser] %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m[omarchy-session-chooser] %s\033[0m\n' "$*" >&2; exit 1; }

# Root is required to touch /usr/share/sddm and /etc/sddm.conf.d.
if (( EUID != 0 )); then
  exec sudo "$0" "$@" || die "need root (or sudo) to install the session chooser"
fi

plus_src="$OMARCHY_ROOT/fedora/sddm-omarchy-plus"
plus_dir=/usr/share/sddm/themes/omarchy-plus
stock_dir=/usr/share/sddm/themes/omarchy
dropin=/etc/sddm.conf.d/zz-omarchy-plus.conf
marker=/var/lib/omarchy-fedora/session-chooser
sddm_conf=/etc/sddm.conf
upstream="$OMARCHY_ROOT/upstream"
conf_src="$upstream/etc/sddm.conf.d"
lua_src="$upstream/default/sddm/hyprland.lua"
stock_src="$upstream/default/sddm/omarchy"

# --- preconditions --------------------------------------------------------
[ -d "$plus_src" ] || die "no theme source at $plus_src (run this from the omarchy-fedora checkout)"

# A default (greetd) install has no SDDM assets: publish the stock Omarchy
# theme and its config from the vendored tree, exactly as
# install.sh --with-session-chooser does, before the plus theme symlinks the
# artwork. Idempotent when they are already there.
if [ -d "$stock_src" ]; then
  log "Installing the stock Omarchy SDDM theme + config from $stock_src"
  mkdir -p "$stock_dir" /etc/sddm.conf.d /usr/share/sddm
  cp -a "$stock_src"/. "$stock_dir"/
  [ -d "$conf_src" ] && cp -a "$conf_src"/. /etc/sddm.conf.d/
  [ -f "$lua_src" ] && cp -a "$lua_src" /usr/share/sddm/hyprland.lua
  chown -R root:root "$stock_dir"
  [ -d "$conf_src" ] && chown -R root:root /etc/sddm.conf.d
  [ -f "$lua_src" ] && chown root:root /usr/share/sddm/hyprland.lua
fi
[ -d "$stock_dir" ] || die "stock omarchy SDDM theme missing at $stock_dir; run 'omarchy update' (or install.sh) first, then retry"

# --- 1. publish the canonical omarchy-plus theme --------------------------
log "Installing the omarchy-plus SDDM greeter (session + username choice)"
mkdir -p "$plus_dir"
# Replace the theme files wholesale: a hand-installed copy (the reference
# project's `make install` writes a different Main.qml) must not linger. Artwork
# stays symlinked to the stock theme so omarchy-plymouth-set recolors track.
rm -f "$plus_dir/Main.qml" "$plus_dir/metadata.desktop" "$plus_dir/theme.conf"
cp -a "$plus_src/Main.qml" "$plus_src/metadata.desktop" "$plus_src/theme.conf" "$plus_dir"/
for art in logo.png lock.png lock-failed.png entry.png entry-failed.png bullet.png; do
  ln -sfn "$stock_dir/$art" "$plus_dir/$art"
done
chown -R root:root "$plus_dir"

# --- 2. select it and record the opt-in -----------------------------------
mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=omarchy-plus\n' > "$dropin"
chown root:root "$dropin"
mkdir -p /var/lib/omarchy-fedora
printf 'plus\n' > "$marker"

# --- 2b. make SDDM the display manager again ------------------------------
# greetd (the Omarchy login screen) is the default; the chooser is an SDDM
# theme, so take the display-manager alias back and stop greetd starting.
log "Switching the display manager from greetd to SDDM"
systemctl enable --force sddm.service || warn "could not enable sddm.service"
systemctl disable greetd.service 2>/dev/null || true

# --- 3. disable the leftover SDDM autologin -------------------------------
# Autologin bypasses the greeter, so the chooser can't be reached at boot.
if [ -f /etc/sddm.conf.d/autologin.conf ]; then
  log "Removing /etc/sddm.conf.d/autologin.conf (autologin bypasses the greeter)"
  rm -f /etc/sddm.conf.d/autologin.conf
fi

# Comment the active [Autologin] keys in /etc/sddm.conf (only that section).
if [ -f "$sddm_conf" ] \
   && grep -qE '^[[:space:]]*(Session|User|Relogin)[[:space:]]*=' "$sddm_conf"; then
  log "Disabling SDDM autologin in $sddm_conf (backup: ${sddm_conf##*/}.omarchy-session-chooser.bak)"
  cp -a "$sddm_conf" "${sddm_conf}.omarchy-session-chooser.bak"
  python3 - "$sddm_conf" <<'PYEOF'
import re, sys
path = sys.argv[1]
out, in_autologin = [], False
with open(path) as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_autologin = (stripped == "[Autologin]")
            out.append(line)
            continue
        if in_autologin and re.match(r"^[ \t]*(Session|User|Relogin)[ \t]*=", line):
            out.append("# omarchy-session-chooser: " + line)
            continue
        out.append(line)
with open(path, "w") as f:
    f.writelines(out)
PYEOF
else
  log "No SDDM autologin configured (already correct)"
fi

log "Done. The session chooser appears at the next login; Omarchy is still preselected."
log "Revert: sudo ./fedora/scripts/install.sh --without-session-chooser  (returns to the greetd Omarchy login screen; restore ${sddm_conf}.omarchy-session-chooser.bak to re-enable autologin)"
