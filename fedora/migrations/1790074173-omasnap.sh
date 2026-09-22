#!/bin/bash
# Omasnap replaces Satty/Tensaku for screenshots. Upstream does this in
# migrations/1788129995.sh; the Fedora port never runs it (pacman-based), so
# this is the Fedora-native equivalent for the user-facing parts. The omasnap
# package itself lands via the first-party COPR backfill; the layer rule and the
# default imv config already ship in the synced upstream tree.
#
# Upstream also drops satty and tensaku; the Fedora port keeps packaging tensaku
# for now, so it is intentionally not removed here.
set -euo pipefail

user="${SUDO_USER:-}"
if [ -z "$user" ] || [ "$user" = root ]; then
  user="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)"
fi
[ -n "$user" ] || { echo "omasnap: no user to configure; skipping" >&2; exit 0; }

home="$(getent passwd "$user" | cut -d: -f6)"

# The old source installer left a NoDisplay entry that overrides the packaged
# launcher. Run as the user so we never touch their files as root.
runuser -u "$user" -- env HOME="$home" \
  rm -f "$home/.local/share/applications/omasnap.desktop"

# Point imv's edit shortcut at Omasnap instead of tensaku-edit/satty.
imv_config="$home/.config/imv/config"
if [ -f "$imv_config" ]; then
  runuser -u "$user" -- env HOME="$home" \
    sed -i \
    -e 's/^# Edit the current image in Tensaku and quit the viewer$/# Edit the current image in Omasnap and quit the viewer/' \
    -e 's/^# Edit the current image in Satty and quit the viewer$/# Edit the current image in Omasnap and quit the viewer/' \
    -e 's|^<Ctrl+e> = exec tensaku-edit "$imv_current_file" & ; quit$|<Ctrl+e> = exec omasnap "$imv_current_file" \& ; quit|' \
    -e 's|^<Ctrl+e> = exec satty --filename "$imv_current_file" & ; quit$|<Ctrl+e> = exec omasnap "$imv_current_file" \& ; quit|' \
    "$imv_config"
fi

echo "omasnap: screenshot editor switched (imv config updated)"
