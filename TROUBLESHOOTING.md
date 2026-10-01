# TROUBLESHOOTING

## Test in a VM first

Never test destructive changes on your daily Fedora/Omarchy system. Create a
disposable Fedora VM (see `docs/ARCH_SPECIFIC_INVENTORY.md` and the CI
integration-test for the intended golden-VM model).

## The installer fails at "Installing required repositories"

- Confirm dnf-plugins-core is present (`dnf install -y 'dnf-command(copr)'`).
- Confirm network access to `copr.fedorainfracloud.org`.
- If the COPR can't reach the Fedora release, ensure you're on x86_64 and a
  supported Fedora version.

## Package not found during install

- The package lacks a Fedora mapping, or the COPR isn't enabled.
- Check `fedora/mappings/packages.yaml` classification; run:
  ```bash
  python3 fedora/scripts/lib/resolve.py --package <name>
  ```

## `--dry-run` says "network check failed"

- Verify DNS + general connectivity before installing.

## Hyprland doesn't start after reboot

- The installer preselects the Omarchy session for the installing user via
  `/var/lib/sddm/state.conf` (`[Last] Session=omarchy.desktop`). If you log in
  as a different account, or the session was changed later, edit that file (or
  re-run the installer) to point `Session=` at `omarchy.desktop`. The stock
  Omarchy greeter theme has no session picker, so there is no on-screen way to
  choose it.
- Check logs: `journalctl -b -u hyprland` or the session log.
- GPU drivers: on NVIDIA use `--nvidia` to enable RPM Fusion + akmod-nvidia.
- This is not yet validated in a VM; see QUATTRO_FEATURES.md status.

## An empty black window (Xwayland) on the Omarchy desktop

- On a **KDE Plasma** base, `xwaylandvideobridge` autostarts into the Omarchy
  session (its KDE autostart file is missing the `OnlyShowIn=KDE` guard) and
  creates an unclosable X11 helper window through Xwayland. It is only useful
  on Plasma, so the installer masks it with a user-level
  `~/.config/autostart/org.kde.xwaylandvideobridge.desktop` (`Hidden=true`).
  Re-run the installer (or `omarchy update`) if it reappears.
- Do **not** remove `xorg-x11-server-Xwayland`: it is needed for X11 apps and
  games. The black window is the bridge, not Xwayland itself.

## Fingerprint setup fails with "pacman: command not found"

- The installer rewrites upstream's `omarchy-setup-security-fingerprint` to
  install `fprintd`, `fprintd-pam`, `libfprint`, and `usbutils` through dnf. If
  you still see pacman, re-run the installer (or `omarchy update`) so the
  Fedora override is (re)generated at
  `/usr/share/omarchy/bin/omarchy-setup-security-fingerprint`.
- `fprintd-pam` is required: it ships `pam_fprintd.so`, which the PAM stacks
  reference; installing `fprintd` alone is not enough on Fedora.

## Omarchy CLI commands missing

First-party binaries aren't packaged yet. Expect `omarchy ...` and related
commands to be absent until the BUILD_FROM_SOURCE RPM effort lands.

## Upstream sync conflicts

Run the sync classification in `UPSTREAM.md`. If a Fedora-patched file
conflicts, stop automatic merge and review manually via the created issue.

## How to report

Provide: Fedora version, `fedora/scripts/lib/resolve.py --package <x>` output,
the failing command, and full error output.
