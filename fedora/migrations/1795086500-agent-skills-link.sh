#!/bin/bash
# Link every agent skill from the Omarchy tree in use.
#
# Upstream does this in migrations/1794988405.sh: run omarchy-agent-skills-link
# so skills shipped since first login reach existing installs and a dev-linked
# checkout's agents keep reading the package's copies. The command is
# distro-neutral (it only rewrites skill symlinks under the user's home), so the
# Fedora port runs the same command, once per human user. Idempotent.
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
  runuser -u "$user" -- env HOME="$home" OMARCHY_PATH=/usr/share/omarchy \
    /usr/share/omarchy/bin/omarchy-agent-skills-link \
    && echo "agent-skills-link: linked agent skills for $user"
done

echo "agent-skills-link: agent skills linked for all human users"
