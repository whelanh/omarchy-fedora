#!/bin/bash
# Folio ("Files") replaces Nautilus as the file manager.
#
# Upstream does this in migrations/1794330979.sh: install folio, repoint personal
# mimeapps entries at folio.desktop, re-pin a dock that still pins Nautilus, and
# drop nautilus, nautilus-python, nautilus-dropbox and sushi. The Fedora port
# never runs the pacman-based upstream migrations, so this is the Fedora-native
# equivalent.
#
# Package install and removal are already covered on Fedora: folio is a
# first-party RPM that omarchy_fedora_install_firstparty installs on this same
# update, and nautilus/nautilus-python/sushi are pruned because they are listed
# in fedora/mappings/retired-packages.conf. What is left is the per-user state:
# a personal mimeapps.list or dock pin still names Nautilus and would win over
# the packaged defaults.
set -euo pipefail

# Bail out *unsuccessfully* if the file manager is missing: update.sh records a
# marker only on exit 0, and repointing a user's association at a desktop file
# that is not installed would leave them with no file manager. 75 (EX_TEMPFAIL)
# says "not now, retry later", so the update reports it as deferred instead of
# failed. (This window is real: while the RPM is unpublished,
# retired-replacements.conf also keeps nautilus installed, so nobody loses a
# file manager in the meantime.)
#
# Check the desktop file, not `rpm -q folio`: Fedora has its own unrelated
# `folio` package (Toolstack's note-taking app), and the first release of this
# migration trusted that name, saw Fedora's package, recorded itself as done on
# machines that had no file manager at all. Our RPM is now omarchy-folio, but
# the app-facing contract is folio.desktop, so test that.
#
# This is also why the file was re-dated (1794412800 -> 1794581000): the marker
# name includes the timestamp, so every machine that recorded the broken run
# runs the corrected one on its next update. Everything below is idempotent.
if [ ! -f /usr/share/applications/folio.desktop ]; then
  echo "folio-replaces-nautilus: the Files app is not installed yet; deferring to the next update" >&2
  exit 75
fi

# Dependency-aware removal, like omarchy_fedora_prune_retired. Honor the
# documented opt-out so NO_PRUNE machines keep Nautilus.
if [ -z "${OMARCHY_FEDORA_NO_PRUNE:-}" ]; then
  for pkg in nautilus nautilus-python sushi; do
    rpm -q "$pkg" >/dev/null 2>&1 || continue
    if rpm -e --test "$pkg" >/dev/null 2>&1; then
      echo "folio-replaces-nautilus: removing $pkg"
      dnf -y remove "$pkg" || \
        echo "folio-replaces-nautilus: dnf remove $pkg failed; prune_retired will retry" >&2
    else
      echo "folio-replaces-nautilus: leaving $pkg installed (still required by another package)" >&2
    fi
  done
fi

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

  for file in "$home/.config/mimeapps.list" \
              "$home/.local/share/applications/mimeapps.list"; do
    [ -f "$file" ] || continue
    grep -q 'org\.gnome\.Nautilus\.desktop' "$file" || continue
    runuser -u "$user" -- env HOME="$home" \
      sed --follow-symlinks -i \
        's/org\.gnome\.Nautilus\.desktop/folio.desktop/g' "$file" \
      && echo "folio-replaces-nautilus: repointed $file for $user"
  done

  # A dock entry that still pins Nautilus pins Files instead.
  shell_json="$home/.config/omarchy/shell.json"
  if [ -f "$shell_json" ] && grep -q '"org\.gnome\.Nautilus"' "$shell_json"; then
    runuser -u "$user" -- env HOME="$home" \
      sed --follow-symlinks -i \
        's/"org\.gnome\.Nautilus"/"folio"/g' "$shell_json" \
      && echo "folio-replaces-nautilus: repointed the dock pin in $shell_json"
  fi

  # Make Files the directory handler. On Arch this comes from the packaged
  # /usr/share/applications/mimeapps.list, but on Fedora that path belongs to
  # shared-mime-info, so nothing set inode/directory and an arbitrary app that
  # merely lists MimeType=inode/directory (disktree) won the association.
  # xdg-mime edits the user's own mimeapps.list in place and is idempotent.
  if command -v xdg-mime >/dev/null 2>&1; then
    current="$(runuser -u "$user" -- env HOME="$home" \
      xdg-mime query default inode/directory 2>/dev/null || true)"
    if [ "$current" != folio.desktop ]; then
      runuser -u "$user" -- env HOME="$home" \
        xdg-mime default folio.desktop inode/directory \
        && echo "folio-replaces-nautilus: made Files the directory handler for $user"
    fi
  fi
done

echo "folio-replaces-nautilus: Files now handles directories (was Nautilus)"
