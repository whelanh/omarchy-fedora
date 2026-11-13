#!/bin/bash
# Put existing docks back on Omarchy's default pins.
#
# Upstream 00147cf6d ("Pin Omarchy's own apps in the default dock", #18667,
# 2026-11-12) replaced the shipped pins - foot, X and YouTube out; Omarchy's own
# terminal/browser, hype, monologue and cliamp in - but shipped no migration, so
# a machine that had already copied the old default into
# ~/.config/omarchy/shell.json keeps it. The port makes that permanent:
# install.sh seeds ~/.config once with `cp -a -n`, so the dock is frozen at
# install time. Installs that predate #18667 therefore show the old icons on
# floating workspaces forever, while a fresh native Omarchy shows the new ones.
#
# Dropping dock.pinned (instead of pasting the new list) hands the dock back to
# the packaged default: DockModel.pinnedIds falls back to it whenever the key is
# absent, so the dock also follows later upstream default changes. A dock the
# user has customized no longer matches a legacy default, and is left alone -
# see fedora/scripts/lib/dock-pins.py for the exact match.
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd -- "$here/../.." && pwd)"
helper="$root/fedora/scripts/lib/dock-pins.py"

command -v python3 >/dev/null 2>&1 || {
  echo "dock-pins: python3 is missing; leaving docks untouched" >&2
  exit 0
}
[ -f "$helper" ] || {
  echo "dock-pins: no helper at $helper; skipping" >&2
  exit 0
}

# All human users (uid 1000-60000), plus SUDO_USER first if set. The dock lives
# in $HOME, so root must never rewrite it as itself.
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
  file="$home/.config/omarchy/shell.json"
  [ -s "$file" ] || continue

  # --check is silent: exit 1 means "not one of the shipped defaults", which is
  # the user's own dock and none of our business.
  runuser -u "$user" -- python3 "$helper" --check "$file" || continue
  runuser -u "$user" -- python3 "$helper" --fix "$file" || continue
  echo "dock-pins: $user's dock follows Omarchy's default pins again"

  # Best effort: let a running shell pick the change up without a relogin.
  uid="$(id -u "$user")"
  if [ -x /usr/share/omarchy/bin/omarchy-shell ]; then
    runuser -u "$user" -- env HOME="$home" \
      XDG_RUNTIME_DIR="/run/user/$uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
      PATH="/usr/share/omarchy/bin:/usr/bin:/bin" \
      /usr/share/omarchy/bin/omarchy-shell -q shell reloadConfig 2>/dev/null || true
  fi
done

echo "dock-pins: legacy default docks handed back to upstream's defaults"
