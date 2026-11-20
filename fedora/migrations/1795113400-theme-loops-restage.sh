#!/bin/bash
# Give the current theme its packaged background loops.
#
# Upstream does this in migrations/1795113315.sh: omarchy-themes-loops is
# installed by 1795093470, but the theme in use is a copy staged by
# omarchy-theme-set, so its loops only arrive with the next theme switch, and
# that migration refreshes the staged theme to pick them up.
#
# On Fedora the package arrives through install.sh's first-party backfill, so
# the only missing piece is the staged theme. Upstream calls
# omarchy-theme-refresh for that; the port copies the loops directory instead,
# which is exactly what omarchy-theme-set itself does with packaged loops
# (`cp -r $OMARCHY_PACKAGED_THEMES_PATH/$theme/backgrounds/loops ...`). The copy
# is deterministic and needs no Hyprland session, while a theme refresh from
# root has no session environment to work with. A later theme switch restages
# everything anyway. Idempotent: an existing loops directory is left alone.
set -euo pipefail

# The staged theme can only get its loops once the package is installed. The
# first-party backfill installs it on this same update; if the COPR has not
# published it yet, defer instead of recording the migration as done.
if ! rpm -q omarchy-themes-loops >/dev/null 2>&1; then
  echo "theme-loops-restage: omarchy-themes-loops is not installed yet; retrying on the next update" >&2
  exit 75
fi

# All human users (uid 1000-60000), plus SUDO_USER first if set. Theme state is
# per user, so root must never write into another user's HOME.
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

  state="$home/.local/state/omarchy/current"
  theme=$(cat "$state/theme.name" 2>/dev/null || true)
  [ -n "$theme" ] || continue

  staged="$state/theme/backgrounds"
  packaged="/usr/share/omarchy/themes/$theme/backgrounds/loops"
  [ -d "$staged" ] && [ -d "$packaged" ] || continue
  [ -d "$staged/loops" ] && continue

  runuser -u "$user" -- env HOME="$home" cp -r "$packaged" "$staged/" \
    && echo "theme-loops-restage: $user's $theme theme now has its background loops"
done

echo "theme-loops-restage: current themes carry their packaged background loops"
