#!/bin/bash
# Qt apps are themed by qtengine instead of the GTK platform theme.
#
# Upstream does this in migrations/1792902457.sh: install qtengine, seed
# ~/.config/qtengine/config.json, and refresh the current theme so its
# qtengine.colors is rendered. The Fedora port never runs the pacman-based
# upstream migrations, so this is the Fedora-native equivalent.
#
# Two of the three steps are already covered on Fedora:
#   - qtengine is backfilled from fedora/packages/desktop.txt on this same
#     update (install.sh --update -> backfill_packages), and
#   - config/qtengine/config.json is seeded by install.sh's `cp -a -n config/`
#     step, which runs before Fedora migrations do.
# What is left is the theme refresh: the current theme was staged before
# qtengine.colors.tpl existed, so without it qtengine finds no color scheme and
# Qt apps stay unthemed until the user switches themes.
set -euo pipefail

if ! rpm -q qtengine >/dev/null 2>&1; then
  echo "qtengine-qt-theming: qtengine not installed yet; nothing to configure" >&2
  exit 0
fi

if ! command -v omarchy-theme-refresh >/dev/null 2>&1; then
  echo "qtengine-qt-theming: omarchy-theme-refresh missing; skipping theme refresh" >&2
  exit 0
fi

# All human users (uid 1000-60000), plus SUDO_USER first if set. Theme state is
# per user, so root must never render into another user's HOME.
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
  # install.sh seeds this on update; do it again in case the config tree seed
  # was skipped, and never touch a config the user already wrote.
  config="$home/.config/qtengine/config.json"
  if [ ! -e "$config" ] && [ ! -L "$config" ]; then
    runuser -u "$user" -- env HOME="$home" mkdir -p "$home/.config/qtengine"
    runuser -u "$user" -- env HOME="$home" \
      install -Dm644 /usr/share/omarchy/config/qtengine/config.json "$config" \
      || echo "qtengine-qt-theming: could not seed $config" >&2
  fi
  # Renders the theme's qtengine.colors so the palette applies on next login.
  runuser -u "$user" -- env HOME="$home" omarchy-theme-refresh \
    || echo "qtengine-qt-theming: theme refresh failed for $user; a theme switch will fix it" >&2
done

echo "qtengine-qt-theming: Qt apps now follow the Omarchy theme through qtengine"
