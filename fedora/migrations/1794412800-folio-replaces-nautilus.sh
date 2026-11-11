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

if ! rpm -q folio >/dev/null 2>&1; then
  echo "folio-replaces-nautilus: folio not installed yet; nothing to configure" >&2
  exit 0
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
done

echo "folio-replaces-nautilus: Files now handles directories (was Nautilus)"
