#!/bin/bash
# Papers replaces Evince as the document viewer.
#
# Upstream does this in migrations/1794165002.sh: install papers, drop evince,
# and repoint personal mimeapps entries at org.gnome.Papers.desktop (a per-user
# mimeapps.list still wins over the packaged one). The Fedora port never runs
# the pacman-based upstream migrations, so this is the Fedora-native
# equivalent. papers is backfilled from fedora/packages/applications.txt and
# evince is pruned by fedora/mappings/retired-packages.conf on the same update;
# this makes the migration self-contained and rewrites the user associations.
set -euo pipefail

if ! rpm -q papers >/dev/null 2>&1; then
  echo "papers-replaces-evince: installing papers"
  dnf -y install papers || { echo "papers-replaces-evince: papers install failed; will retry next update" >&2; exit 1; }
fi

# Dependency-aware removal, like omarchy_fedora_prune_retired. Honor the
# documented opt-out so NO_PRUNE machines keep evince.
if [ -z "${OMARCHY_FEDORA_NO_PRUNE:-}" ] && rpm -q evince >/dev/null 2>&1; then
  if rpm -e --test evince >/dev/null 2>&1; then
    echo "papers-replaces-evince: removing evince"
    dnf -y remove evince || echo "papers-replaces-evince: dnf remove failed; prune_retired will retry" >&2
  else
    echo "papers-replaces-evince: leaving evince installed (still required by another package)" >&2
  fi
fi

repoint_mimeapps() {
  local user="$1" home="$2" file
  for file in "$home/.config/mimeapps.list" \
              "$home/.local/share/applications/mimeapps.list"; do
    [ -f "$file" ] || continue
    grep -q 'org\.gnome\.Evince\.desktop' "$file" || continue
    # Run as the user: root must never rewrite their files (or leave root-owned
    # inodes behind after `sed -i`).
    runuser -u "$user" -- env HOME="$home" \
      sed --follow-symlinks -i \
        's/org\.gnome\.Evince\.desktop/org.gnome.Papers.desktop/g' "$file"
    echo "papers-replaces-evince: repointed $file for $user"
  done
}

# All human users (uid 1000-60000), plus SUDO_USER first if set.
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
  repoint_mimeapps "$user" "$home" \
    || echo "papers-replaces-evince: mimeapps migration failed for $user; continuing" >&2
done

echo "papers-replaces-evince: document viewer switched to Papers"
