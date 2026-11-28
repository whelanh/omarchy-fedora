#!/bin/bash
# Switch from SDDM to greetd + the Omarchy login screen, unless the user opted
# into the SDDM omarchy-plus session chooser.
#
# This is the display-manager half of upstream 1795834060.sh. The boot-splash
# half stays Fedora's Plymouth: upstream's splash is an mkinitcpio hook, while
# the port builds its initramfs with dracut (fedora/system/dracut/50-omarchy.conf).
#
# Idempotent. install.sh --update converges the same state; this records the
# one-time switch for machines whose update runs it after the userspace sync.
set -euo pipefail

# The opt-in session chooser is SDDM; leave it alone.
if [ -e /var/lib/omarchy-fedora/session-chooser ]; then
  echo "greetd: the session chooser is enabled; keeping SDDM"
  exit 0
fi

PAM=/usr/share/omarchy/etc/pam.d/omarchy-login
SYSLOGIN=/usr/share/omarchy/bin/omarchy-system-login
CFG=/etc/greetd/config.toml

getent passwd greetd >/dev/null 2>&1 || {
  echo "greetd: package not installed; keeping SDDM and retrying next update" >&2
  exit 1
}
[ -f "$SYSLOGIN" ] || {
  echo "greetd: no $SYSLOGIN; keeping SDDM and retrying next update" >&2
  exit 1
}

# The session PAM service greetd names in [general]: it sets the session type
# and desktop before pam_systemd records them.
if [ -f "$PAM" ]; then
  install -Dm644 "$PAM" /etc/pam.d/omarchy-login
fi

# A graphical greeter needs the seat's devices; Fedora's greetd user starts in
# its own group only.
for grp in video render input; do
  getent group "$grp" >/dev/null 2>&1 || continue
  usermod -aG "$grp" greetd 2>/dev/null || true
done

mkdir -p /etc/greetd
if [ -f "$CFG" ] && grep -q 'omarchy/default/splash/greeter' "$CFG"; then
  :
elif systemctl is-enabled --quiet sddm.service 2>/dev/null || [ -f /var/lib/sddm/state.conf ]; then
  bash "$SYSLOGIN" --from-sddm
else
  user=$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd)
  if [ -n "$user" ]; then bash "$SYSLOGIN" "$user"; else bash "$SYSLOGIN" --reset; fi
fi

# Upstream's config names a `greeter` account; Fedora ships `greetd`.
if grep -q '^user = "greeter"$' "$CFG" 2>/dev/null; then
  sed -i 's/^user = "greeter"$/user = "greetd"/' "$CFG"
fi
chmod 0644 "$CFG"

systemctl enable --force greetd.service
systemctl disable sddm.service 2>/dev/null || true

echo "greetd: the Omarchy login screen takes over from SDDM on the next boot"
echo "        (reboot when convenient; the current session is untouched)"
