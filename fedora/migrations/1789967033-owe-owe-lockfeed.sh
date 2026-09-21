#!/bin/bash
# OWE desktop video backgrounds + lock feed: wire the user side, which the
# upstream migration (migrations/1789764927.sh) does but the Fedora port never
# runs (it is pacman-based).
#
# The `owe` and `owe-lockfeed` RPMs land via the first-party COPR backfill; this
# installs the theme-set hook, enables the owed user service, and starts it in a
# live session. Idempotent: reinstalling the same hook and enabling an already
# enabled unit are no-ops.
set -euo pipefail

OMARCHY_PATH=/usr/share/omarchy
export OMARCHY_PATH

HOOK=/usr/share/owe/10-owe-sync
UNIT=/usr/lib/systemd/user/owed.service

# Without the package there is nothing to wire; not an error.
[ -f "$UNIT" ] || {
  echo "owe: package not installed; skipping service/hook wiring" >&2
  exit 0
}

user="${SUDO_USER:-}"
if [ -z "$user" ] || [ "$user" = root ]; then
  user="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)"
fi
[ -n "$user" ] || { echo "owe: no user to configure; skipping" >&2; exit 0; }

home="$(getent passwd "$user" | cut -d: -f6)"
uid="$(id -u "$user")"
runtime="/run/user/$uid"

as_user() {
  runuser -u "$user" -- env \
    HOME="$home" \
    OMARCHY_PATH="$OMARCHY_PATH" \
    XDG_RUNTIME_DIR="$runtime" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
    PATH="$OMARCHY_PATH/bin:/usr/bin:/bin" \
    "$@"
}

# Theme-set hook (the packaged unit ships it; copy only if present).
hook_dir="$home/.config/omarchy/hooks/theme-set.d"
if [ -f "$HOOK" ]; then
  as_user mkdir -p "$hook_dir"
  as_user cp "$HOOK" "$hook_dir/10-owe-sync"
  as_user chmod 755 "$hook_dir/10-owe-sync"
fi

# Enable the user service via the live user manager, falling back to the
# graphical-session.target.wants symlink upstream uses when it is unavailable
# (e.g. an update from a TTY with no user manager running).
if as_user systemctl --user daemon-reload 2>/dev/null \
   && as_user systemctl --user enable owed.service 2>/dev/null; then
  :
else
  wants="$home/.config/systemd/user/graphical-session.target.wants"
  as_user mkdir -p "$wants"
  as_user ln -sfn "$UNIT" "$wants/owed.service"
fi

# Start it now, but only from a live graphical session: a TTY update must not
# start a renderer against a missing Wayland session.
if [ "${OMARCHY_UPGRADE_TO_QUATTRO_LIVE:-0}" != 1 ] \
   && as_user systemctl --user is-active --quiet graphical-session.target 2>/dev/null; then
  as_user systemctl --user start owed.service || true
fi

echo "owe: theme hook installed and owed.service enabled"
