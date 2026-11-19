#!/bin/bash
# Turn off herdr's own update check, since dnf updates herdr.
#
# Upstream does this in migrations/1794938310.sh: append
# [update]\nversion_check = false to ~/.config/herdr/config.toml unless the user
# already set [update] (their choice) or the config is unreadable. The reason is
# the same on Fedora: herdr ships from the whelanh/omarchy COPR and dnf upgrades
# it, so herdr's own check would only nag. The edit is distro-neutral and
# idempotent, so the port runs it once per human user.
set -euo pipefail

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
  config="$home/.config/herdr/config.toml"
  [ -f "$config" ] || continue

  # Dotfile managers may own the file or a parent directory through a symlink;
  # preserve that layout rather than detaching or editing its target.
  path="$config"
  skip=0
  while [[ $path != "$home" && $path != / ]]; do
    if [[ -L $path ]]; then
      echo "herdr-update-check: preserving symlink-managed herdr config for $user"
      skip=1
      break
    fi
    path=$(dirname "$path")
  done
  (( skip )) && continue

  # Read as TOML, not as text, so quoted keys and strings can't fool the check.
  # A user who set anything under [update] made their own choice, and a config
  # herdr can't parse is theirs to fix, so both are left alone.
  state=$(runuser -u "$user" -- env HOME="$home" python3 -c \
    'import sys,tomllib; print("set" if "update" in tomllib.load(open(sys.argv[1],"rb")) else "unset")' \
    "$config" 2>/dev/null || true)

  if [[ $state == "unset" ]]; then
    runuser -u "$user" -- env HOME="$home" bash -c \
      'printf "\n[update]\nversion_check = false\n" >>"$1"' _ "$config" \
      && echo "herdr-update-check: disabled herdr's update check for $user"
    # Best-effort reload: a running server only needs a reload, so a failed
    # reload is not a failed migration.
    runuser -u "$user" -- env HOME="$home" PATH="/usr/share/omarchy/bin:/usr/bin:/bin" \
      omarchy-restart-herdr 2>/dev/null || true
  fi
done

echo "herdr-update-check: herdr update check disabled where it was unset"
