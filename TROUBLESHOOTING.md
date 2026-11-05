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

## "Failed to enable unit ... display-manager.service already exists and is a symlink to .../plasmalogin.service"

- Fedora 44+ **KDE** bases use Plasma Login Manager instead of SDDM, and it owns
  the `display-manager.service` alias. A plain `systemctl enable sddm` cannot
  replace it, so the Omarchy greeter assets are installed but never shown and the
  machine keeps PLM (which is fixed to the Breeze theme and has no Omarchy
  theme). The installer handles this by disabling GDM/LightDM/LXDM/PLM and
  running `systemctl enable --force sddm.service`. If you hit it on an older
  install, re-run the installer (or `omarchy update`). To switch back to SDDM
  manually (Fedora's documented path):
  ```bash
  sudo systemctl disable plasmalogin.service
  sudo systemctl enable --force sddm.service
  sudo systemctl reboot
  ```
- Your KDE session entry is preserved, so you can still choose it from the SDDM
  session list if you enable the session chooser (below).

## "Two world clocks" / duplicate bar widget

- Upstream moved the world clock in-tree as `omarchy.elsewhen` and dropped the
  separate `elsewhen` package. Older Fedora installs had the out-of-tree
  `omacom.elsewhen` RPM, which duplicated the widget. `omarchy update` now runs
  a migration that renames `omacom.elsewhen` → `omarchy.elsewhen` (keeping your
  cities/settings), deduplicates, and removes the retired RPM. If you still see
  two, run `sudo ./fedora/scripts/update.sh` (or `omarchy update`) and reboot.

## I want a session picker at the login screen

- The stock Omarchy greeter logs straight into Omarchy and has no picker. On a
  machine converted from KDE/Sway/GNOME you may want the choice back. Install the
  opt-in theme:
  ```bash
  sudo ./fedora/scripts/install.sh --with-session-chooser
  ```
  It keeps the Omarchy look but adds a session picker and username field, and
  leaves the stock theme untouched. Revert with `--without-session-chooser`. See
  `fedora/sddm-omarchy-plus/README.md`.

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

## `snapshot check failed. not adding snapshot N` during `omarchy update`

- This comes from snapper, not Omarchy. It keeps a snapshot in its list only
  while `/.snapshots/N/snapshot` is a btrfs subvolume root; if a deletion,
  rollback or interrupted cleanup left `info.xml` behind without the subvolume,
  snapper skips that number and repeats the warning on every run.
- It does not block the update: the pre-update snapshot is still created (for
  the next free number) and the upgrade continues. But snapper will never clean
  up the orphan automatically, so remove the metadata-only directory.
- `omarchy update` detects these and prints the exact command. Confirm first,
  then remove it:
  ```bash
  sudo btrfs subvolume show /.snapshots/115/snapshot
  sudo rm -rf /.snapshots/115
  ```
  Only remove a number when `btrfs subvolume show` reports that the path is not
  a subvolume (or does not exist). Never remove `/.snapshots` itself.

## How to report

Provide: Fedora version, `fedora/scripts/lib/resolve.py --package <x>` output,
the failing command, and full error output.
