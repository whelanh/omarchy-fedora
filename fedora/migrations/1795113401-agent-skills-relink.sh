#!/bin/bash
# Relink agent skills for the omarchy-make-* and omarchy-contribute skills.
#
# Upstream does this in migrations/1795093910.sh: web-game and omarchy-app
# became omarchy-make-game and omarchy-make-app, and omarchy-make-theme,
# omarchy-make-plugin and omarchy-contribute are new. Relinking drops the links
# to the old names and adds the new ones.
#
# The port already links skills in 1795086500-agent-skills-link.sh, but that
# ran against the tree of its day, so the skills shipped since then need
# another pass. The command is distro-neutral (it only rewrites skill symlinks
# under the user's home), so the port runs it once per human user.
set -euo pipefail

# The userspace tree provides the linker; if a sync has not brought it yet,
# defer rather than failing the whole migration.
if [ ! -x /usr/share/omarchy/bin/omarchy-agent-skills-link ]; then
  echo "agent-skills-relink: omarchy-agent-skills-link is missing; retrying on the next update" >&2
  exit 75
fi

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
  runuser -u "$user" -- env HOME="$home" OMARCHY_PATH=/usr/share/omarchy \
    /usr/share/omarchy/bin/omarchy-agent-skills-link \
    && echo "agent-skills-relink: relinked agent skills for $user"
done

echo "agent-skills-relink: agent skills relinked for all human users"
