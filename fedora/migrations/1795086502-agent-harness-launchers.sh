#!/bin/bash
# Add launchers for the agent harnesses already installed.
#
# Upstream does this in migrations/1794931275.sh: harnesses installed before the
# per-harness launcher shipped get theirs here, leaving any launcher already in
# place alone. Distro-neutral (it only writes omarchy-agent-*.desktop launchers
# under the user's home), so the Fedora port runs it once per human user.
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
  for entry in /usr/share/omarchy/default/applications/omarchy-agent-*.desktop; do
    [ -f "$entry" ] || continue
    name=${entry##*/}
    agent=${name#omarchy-agent-}
    agent=${agent%.desktop}
    [ -e "$home/.local/share/applications/$name" ] && continue
    if runuser -u "$user" -- env HOME="$home" OMARCHY_PATH=/usr/share/omarchy \
         PATH="/usr/share/omarchy/bin:/usr/bin:/bin" \
         omarchy-default-agent --installed "$agent" 2>/dev/null; then
      runuser -u "$user" -- env HOME="$home" OMARCHY_PATH=/usr/share/omarchy \
        PATH="/usr/share/omarchy/bin:/usr/bin:/bin" \
        omarchy-agent-launcher "$agent" \
        && echo "agent-harness-launchers: added $name for $user"
    fi
  done
done

echo "agent-harness-launchers: launchers added for installed agent harnesses"
