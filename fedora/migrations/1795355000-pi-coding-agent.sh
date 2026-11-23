#!/bin/bash
# Pi ships as a package, not a mise tool.
#
# Upstream 1795318856: Pi moved from Omarchy's mise declarations into
# omarchy-base.packages as pi-coding-agent, which the first-party backfill
# installs on this same update. What is left is the mise side, because mise's
# shims and the port's wrappers come before /usr/bin on PATH: a shim left by the
# dropped declaration fails rather than falling through to the package.
#
# Fedora difference: the port's mise setup (fedora/scripts/lib/mise.sh, run by
# install.sh and the mise-agents migration) wrote ~/.local/bin/pi with
# omarchy-mise-install, so that wrapper has to go too. A Pi installed from a
# config the user wrote is theirs and stays.
set -euo pipefail

# A system mise config that still declares pi wins over any cleanup, exactly as
# upstream waits for its settings package: defer instead of removing and
# reshimming something that would come straight back.
if grep -qsE '^[[:space:]]*pi[[:space:]]*=' /etc/mise/conf.d/*.toml 2>/dev/null; then
  echo "pi-coding-agent: a system mise config still declares pi; retrying on the next update" >&2
  exit 75
fi

# All human users (uid 1000-60000), plus SUDO_USER first if set. The wrapper and
# the mise state live in $HOME, so root must never touch them as itself.
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

  # omarchy-mise-install's wrappers are tiny and all read alike; anything else
  # called pi in ~/.local/bin is the user's.
  wrapper="$home/.local/bin/pi"
  if [ -f "$wrapper" ] &&
     grep -q 'mise use -g --quiet .*pi' "$wrapper" 2>/dev/null &&
     grep -q 'exec mise x' "$wrapper" 2>/dev/null; then
    runuser -u "$user" -- rm -f "$wrapper" \
      && echo "pi-coding-agent: removed $user's mise wrapper for pi"
  fi

  command -v mise >/dev/null 2>&1 || continue

  # Only a Pi that no config declares is the one Omarchy's dropped declaration
  # left behind; `source` is set for an installation the user asked for.
  installed="$(runuser -u "$user" -- env HOME="$home" mise ls pi --json 2>/dev/null || echo '[]')"
  if printf '%s' "$installed" | jq -e 'any(.[]; .source)' >/dev/null 2>&1; then
    continue
  fi
  runuser -u "$user" -- env HOME="$home" mise uninstall --all pi >/dev/null 2>&1 || true
  runuser -u "$user" -- env HOME="$home" mise reshim >/dev/null 2>&1 || true
  echo "pi-coding-agent: dropped mise's pi for $user; /usr/bin/pi is the package"
done

echo "pi-coding-agent: Pi now comes from the package, not mise"
