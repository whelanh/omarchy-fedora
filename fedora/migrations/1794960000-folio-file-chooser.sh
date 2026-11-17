#!/bin/bash
# Other apps' Open and Save dialogs go to Files (Folio 0.5.0's `folio chooser`).
#
# Upstream does this in migrations/1794775358.sh and by shipping the preference
# in config/xdg-desktop-portal/hyprland-portals.conf:
#
#   [preferred]
#   default=hyprland;gtk
#   org.freedesktop.impl.portal.FileChooser=folio;gtk
#
# Folio 0.5.0 adds the xdg-desktop-portal FileChooser backend that line selects
# (the omarchy-folio RPM ships folio.portal and its D-Bus service, so
# xdg-desktop-portal can start `folio chooser` on demand). The port seeds
# ~/.config from the upstream config/ tree with `cp -a -n`, so fresh installs
# get the line; an existing machine keeps the copy it was seeded with, which
# has no FileChooser line and would leave the dialogs with the GTK portal. What
# is left is that per-user edit, exactly as upstream's migration does it.
#
# The preference falls back to gtk, so a machine without Folio still gets a
# working dialog; and a user who already picked a file chooser (their own line,
# or a ~/.config/xdg-desktop-portal/portals.conf instead) keeps it.
set -euo pipefail

# The 0.5.0 RPM is what registers the backend. Before it, the line would point
# at an implementation no portal provides, so defer instead of writing it:
# update.sh records a marker only on exit 0, and 75 (EX_TEMPFAIL) reports the
# migration as deferred rather than failed.
if [ ! -f /usr/share/xdg-desktop-portal/portals/folio.portal ]; then
  echo "folio-file-chooser: Folio 0.5.0 is not installed yet; deferring to the next update" >&2
  exit 75
fi

# All human users (uid 1000-60000), plus SUDO_USER first if set. This edits
# files in $HOME and restarts a user service, so root must never do it as
# itself.
users=""
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
  users="$SUDO_USER"
fi
while IFS=: read -r name _ uid _ _ home _; do
  if [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ]; then
    case " $users " in
      *" $name "*) ;;
      *) users="$users $name" ;;
    esac
  fi
done < /etc/passwd

for user in $users; do
  home="$(getent passwd "$user" | cut -d: -f6)"
  [ -n "$home" ] && [ -d "$home" ] || continue
  conf="$home/.config/xdg-desktop-portal/hyprland-portals.conf"

  # No Omarchy portal config (the user removed it, or never had one): leave the
  # system defaults alone rather than inventing a file for them.
  [ -f "$conf" ] || continue
  # A file chooser is already chosen, by Omarchy's line or by the user.
  if grep -qE '^org\.freedesktop\.impl\.portal\.FileChooser=' "$conf"; then
    continue
  fi
  # The line has to sit under [preferred] to mean anything.
  grep -qx '\[preferred\]' "$conf" || continue
  # A user's own portals.conf outranks this file; do not touch it either.
  if [ -f "$home/.config/xdg-desktop-portal/portals.conf" ]; then
    continue
  fi

  runuser -u "$user" -- sed --follow-symlinks -i \
    '/^\[preferred\]$/a org.freedesktop.impl.portal.FileChooser=folio;gtk' "$conf" \
    && echo "folio-file-chooser: Open and Save dialogs now go to Files for $user"

  # xdg-desktop-portal reads the config when it starts. Restart it only where a
  # session is actually running, so a TTY update just leaves the file in place
  # for the next login.
  uid="$(id -u "$user")"
  runtime="/run/user/$uid"
  if runuser -u "$user" -- env HOME="$home" XDG_RUNTIME_DIR="$runtime" \
       DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
       systemctl --user is-active --quiet xdg-desktop-portal.service 2>/dev/null; then
    runuser -u "$user" -- env HOME="$home" XDG_RUNTIME_DIR="$runtime" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
      systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
  fi
done

echo "folio-file-chooser: Files provides other apps' Open and Save dialogs"
