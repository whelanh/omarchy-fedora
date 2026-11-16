#!/bin/bash
# Omaview replaces imv and mpv as Omarchy's picture viewer and media player.
#
# Upstream does this in migrations/1794774234.sh (9599f7661, "Replace imv and
# mpv with Omaview"): install omaview, remove the old Image Viewer and Media
# Player launchers where they are still as Omarchy shipped them, and drop imv
# and mpv-mpris. mpv stays installed because Omarchy's wallpaper engine, owe,
# plays video wallpapers through it.
#
# Package install and removal are already covered on Fedora: omaview is a
# first-party RPM that omarchy_fedora_install_firstparty installs on this same
# update, and imv/mpv-mpris are pruned because they are listed in
# fedora/mappings/retired-packages.conf (imv only after omaview is installed,
# via retired-replacements.conf). What is left is per-user state: the launcher
# copies install.sh made under ~/.local/share/applications, and mimeapps entries
# naming imv.desktop or mpv.desktop, which would otherwise leave the files with
# no handler now that Omaview is the default.
set -euo pipefail

# Bail out *unsuccessfully* while Omaview is unpublished: update.sh records a
# marker only on exit 0, and 75 (EX_TEMPFAIL) reports the migration as deferred
# instead of failed. The old launchers and associations are still usable until
# the RPM is there.
if [ ! -f /usr/share/applications/omaview.desktop ]; then
  echo "omaview-replaces-imv: Omaview is not installed yet; deferring to the next update" >&2
  exit 75
fi

# Hashes of the launcher files as Omarchy shipped them - the same set upstream's
# migration accepts (imv.desktop and mpv.desktop across versions). Only an
# unmodified copy goes: one the user edited, or linked from their dotfiles, is
# theirs and stays.
is_shipped_launcher() {
  local sum
  sum="$(sha256sum < "$1" | cut -d' ' -f1)"
  case "$sum" in
    120d30326a77e1f23d050e52293d0acf1aeb9499bf9cd47b93996d6e2be99480|\
    a7a75999f161c6a409ff4c5da26ad9c79fc1ffdd4e633aac87f972ad72fc85d4|\
    d105a16b60ecc1c67f6cc37e5bb7831ca8a08d0e602cb64dd4a1386703362385|\
    9844e9d22d1b4b9801965afea1eb250103cfc6f12e6e62e542ac47abd4b8094d)
      return 0
      ;;
  esac
  return 1
}

# All human users (uid 1000-60000), plus SUDO_USER first if set. These rewrites
# touch files in $HOME, so root must never do them as itself.
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

  applications="$home/.local/share/applications"
  for entry in imv.desktop mpv.desktop; do
    file="$applications/$entry"
    [ -f "$file" ] || continue
    [ -L "$file" ] && continue
    if is_shipped_launcher "$file"; then
      rm -f "$file"
      echo "omaview-replaces-imv: removed Omarchy's old $entry launcher for $user"
    fi
  done
  if [ -d "$applications" ]; then
    runuser -u "$user" -- update-desktop-database "$applications" 2>/dev/null || true
  fi

  # A personal association that still names imv/mpv would stop resolving now
  # that imv is gone, so point it at Omaview instead. This is the user's own
  # choice of viewer, not a packaged default, which is why it is rewritten here
  # rather than left to the system mimeapps.list.
  for file in "$home/.config/mimeapps.list" \
              "$home/.local/share/applications/mimeapps.list"; do
    [ -f "$file" ] || continue
    grep -qE 'imv\.desktop|mpv\.desktop' "$file" || continue
    runuser -u "$user" -- env HOME="$home" \
      sed --follow-symlinks -i \
        -e 's/imv\.desktop/omaview.desktop/g' \
        -e 's/mpv\.desktop/omaview.desktop/g' "$file" \
      && echo "omaview-replaces-imv: repointed $file at Omaview for $user"
  done

  # Fill in the types Omaview handles where the user has no handler at all -
  # the Fedora equivalent of upstream's packaged mimeapps.list. Associations
  # that name another app are the user's choice and stay untouched.
  while IFS= read -r mime; do
    [ -n "$mime" ] || continue
    current="$(runuser -u "$user" -- env HOME="$home" \
      xdg-mime query default "$mime" 2>/dev/null || true)"
    [ -n "$current" ] && continue
    runuser -u "$user" -- env HOME="$home" \
      xdg-mime default omaview.desktop "$mime" 2>/dev/null || true
  done < <(sed -n 's/^MimeType=//p' /usr/share/applications/omaview.desktop | tr ';' '\n')
done

echo "omaview-replaces-imv: Omaview is the picture and media viewer (was imv/mpv)"
