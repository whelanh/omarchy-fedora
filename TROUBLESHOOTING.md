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

- Ensure you selected the Omarchy Wayland session at the SDDM greeter.
- Check logs: `journalctl -b -u hyprland` or the session log.
- GPU drivers: on NVIDIA use `--nvidia` to enable RPM Fusion + akmod-nvidia.
- This is not yet validated in a VM; see QUATTRO_FEATURES.md status.

## Omarchy CLI commands missing

First-party binaries aren't packaged yet. Expect `omarchy ...` and related
commands to be absent until the BUILD_FROM_SOURCE RPM effort lands.

## Upstream sync conflicts

Run the sync classification in `UPSTREAM.md`. If a Fedora-patched file
conflicts, stop automatic merge and review manually via the created issue.

## How to report

Provide: Fedora version, `fedora/scripts/lib/resolve.py --package <x>` output,
the failing command, and full error output.
