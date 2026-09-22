#!/bin/bash
# Elsewhen (omacom.elsewhen) world-clock plugin: put its bar widget on installs
# that predate the plugin.
#
# Fresh Fedora installs already have it: the seeded ~/.config/omarchy/shell.json
# carries the widget (it is in upstream's default bar) and the elsewhen RPM
# installs the plugin into the shell's first-party plugin directory,
# /usr/share/omarchy/shell/plugins, where the shell discovers it without a user
# symlink. Existing installs keep their own shell.json (the config seed is
# --no-clobber), so the widget never lands on their bar. This is the Fedora-native
# equivalent of upstream migrations/1790042972.sh, which the port does not run
# because it shells out to pacman.
#
# The first version of this migration (1789878475) checked the plugin at
# /usr/share/omarchy/plugins, where an early elsewhen RPM installed it, and was
# marked done without ever registering it: the shell only scans
# OMARCHY_PATH/shell/plugins. The file was renamed so machines that already ran
# the broken one run this corrected one.
#
# Idempotent: `omarchy bar put` leaves a widget that is already on the bar where
# it is. It also returns 0 when no shell is running, so this runs once and is
# marked done either way (upstream omarchy-migrate semantics).
set -euo pipefail

PLUGIN=/usr/share/omarchy/shell/plugins/omacom.elsewhen
OMARCHY_PATH=/usr/share/omarchy
export OMARCHY_PATH

# Not installed at all (e.g. first-party installs disabled): mark done rather
# than retry forever. But if the elsewhen RPM is present while its plugin is
# missing or still at the pre-1.0.0-2 path, the package needs upgrading - fail
# so the migration retries on the next update instead of silently marking done.
if [ ! -e "$PLUGIN" ]; then
  if rpm -q elsewhen >/dev/null 2>&1; then
    echo "elsewhen: package present but plugin missing from $PLUGIN" >&2
    echo "elsewhen: upgrade the elsewhen RPM (>= 1.0.0-2) and re-run; leaving migration pending" >&2
    exit 1
  fi
  echo "elsewhen: package not installed; skipping bar placement" >&2
  exit 0
fi

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

# Re-scan the plugins so a running shell notices the freshly installed plugin
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
