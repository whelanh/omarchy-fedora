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
# Placement asks the running shell (omarchy bar put), which is the only writer
# of the bar layout. An update copies the userspace tree while the shell is
# live, so the shell can be mid-reload when this runs, and rescanPlugins is
# asynchronous. Both are waited out below; if the widget still cannot be
# placed, the migration fails so it runs again on the next update rather than
# marking itself done with no widget on the bar.
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
shell_json="$home/.config/omarchy/shell.json"

as_user() {
  runuser -u "$user" -- env \
    HOME="$home" \
    OMARCHY_PATH="$OMARCHY_PATH" \
    XDG_RUNTIME_DIR="$runtime" \
    PATH="$OMARCHY_PATH/bin:/usr/bin:/bin" \
    "$@"
}

# Wait for the shell to answer. A tree update can leave it mid-reload, and
# omarchy-shell reports a not-yet-ready shell as "not running". Bounded so an
# update from a TTY with no shell finishes in a few seconds.
ready=0
for (( i = 0; i < 100; i++ )); do
  if pgrep -x quickshell >/dev/null 2>&1 \
     && as_user omarchy-shell shell ping >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.1
done
if (( ready == 0 )); then
  echo "elsewhen: no running shell to place the widget; leaving migration pending" >&2
  exit 1
fi

# rescanPlugins is asynchronous: wait until the shell has actually registered
# the plugin before asking it to place the widget, or the put races the scan.
as_user omarchy-shell -q shell rescanPlugins
registered=0
for (( i = 0; i < 100; i++ )); do
  if as_user omarchy-shell shell listPlugins 2>/dev/null \
       | grep -q '"id":"omacom.elsewhen"'; then
    registered=1
    break
  fi
  sleep 0.1
done
if (( registered == 0 )); then
  echo "elsewhen: shell did not register the plugin; leaving migration pending" >&2
  exit 1
fi

# `omarchy bar put` leaves an existing placement alone and retries a shell that
# is still coming up. The shell persists to shell.json; confirm it landed. A
# silent no-op (shell never answered) must not be recorded as done.
as_user omarchy bar put omacom.elsewhen --before omarchy.clock
placed=0
for (( i = 0; i < 50; i++ )); do
  if grep -q '"omacom.elsewhen"' "$shell_json" 2>/dev/null; then
    placed=1
    break
  fi
  sleep 0.1
done
if (( placed == 0 )); then
  echo "elsewhen: widget was not placed on the bar; leaving migration pending" >&2
  exit 1
fi

echo "elsewhen: placed before the clock (or left where it was)"
