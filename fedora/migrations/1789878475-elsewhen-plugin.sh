#!/bin/bash
# Elsewhen (omacom.elsewhen) world-clock plugin: place its bar widget on
# installs that predate the plugin.
#
# Fresh Fedora installs already have it: the seeded ~/.config/omarchy/shell.json
# carries the widget (it is in upstream's default bar) and the config seed
# creates the ~/.config/omarchy/plugins/omacom.elsewhen symlink. Existing
# installs keep their own shell.json (the config seed is --no-clobber), so the
# widget never lands on their bar. This is the Fedora-native equivalent of
# upstream migrations/1789581661.sh, which the port does not run because it
# shells out to pacman.
#
# Idempotent: `omarchy bar put` leaves a widget that is already on the bar where
# it is. It also returns 0 when no shell is running, so this runs once and is
# marked done either way (upstream omarchy-migrate semantics).
set -euo pipefail

PLUGIN=/usr/share/omarchy/plugins/omacom.elsewhen
OMARCHY_PATH=/usr/share/omarchy
export OMARCHY_PATH

# Nothing to place if the package is not installed (e.g. first-party installs
# disabled). Not an error: mark the migration done rather than retry forever.
[ -e "$PLUGIN" ] || {
  echo "elsewhen: package not installed; skipping bar placement" >&2
  exit 0
}

# Pick the desktop user to act for: the sudo caller, else the first uid>=1000.
user="${SUDO_USER:-}"
if [ -z "$user" ] || [ "$user" = root ]; then
  user="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)"
fi
[ -n "$user" ] || {
  echo "elsewhen: no user to configure; skipping bar placement" >&2
  exit 0
}

home="$(getent passwd "$user" | cut -d: -f6)"
uid="$(id -u "$user")"
runtime="${XDG_RUNTIME_DIR:-/run/user/$uid}"

# Re-scan the plugins so a running shell notices the new ~/.config symlink
# before we ask it to place the widget. -q is best-effort when no shell runs.
runuser -u "$user" -- env \
  HOME="$home" \
  OMARCHY_PATH="$OMARCHY_PATH" \
  XDG_RUNTIME_DIR="$runtime" \
  PATH="$OMARCHY_PATH/bin:/usr/bin:/bin" \
  omarchy-shell -q shell rescanPlugins

# `omarchy bar put` leaves an existing placement alone and returns 0 even when
# no shell is running, matching upstream's migration semantics.
runuser -u "$user" -- env \
  HOME="$home" \
  OMARCHY_PATH="$OMARCHY_PATH" \
  XDG_RUNTIME_DIR="$runtime" \
  PATH="$OMARCHY_PATH/bin:/usr/bin:/bin" \
  omarchy bar put omacom.elsewhen --before omarchy.clock

echo "elsewhen: placed before the clock (or left where it was)"
