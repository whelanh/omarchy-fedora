# UPDATING

## End-user update

`fedora/scripts/update.sh` updates the **Fedora** packages:

```bash
sudo ./fedora/scripts/update.sh
```

It refreshes dnf metadata and upgrades installed packages. It does not blindly
`git pull` a live install.

## Development sync

With `OMARCHY_FEDORA_UPDATE_UPSTREAM=1` in a git checkout, it also pulls the
latest upstream `quattro` subtree:

```bash
OMARCHY_FEDORA_UPDATE_UPSTREAM=1 ./fedora/scripts/update.sh
```

## Upstream change model

- Upstream changes are classified per `UPSTREAM.md`.
- The `upstream-sync` GitHub workflow runs daily and attempts a `SAFE` PR.
- When upstream adds/removes a package, update `fedora/mappings/packages.yaml`
  and re-run `fedora/tests/static.sh`.

## Full target updater (spec section 20)

`omarchy update` on Fedora runs `fedora/scripts/update.sh` (wired via a
`/usr/bin/omarchy-update` shim installed by `install.sh`). It performs:

1. Fetch Fedora repository metadata — `dnf makecache`
2. Update Fedora packages — `dnf upgrade` (now includes the first-party
   binaries shipped as RPMs from the `whelanh/omarchy` COPR)
3. Sync the Omarchy userspace to upstream `quattro` — `git subtree pull`
   (requires a git checkout with the `upstream` remote; skipped otherwise)
4. Re-apply the userspace — `install.sh --update` (idempotent: re-copies the
   tree, re-wires `omarchy-*` onto PATH, re-installs the uwsm-app / chromium /
   sudoers / fonts compat shims, validates)
5. Migrations — `omarchy_fedora_migrate` runs our **Fedora-native** migrations
   (`fedora/migrations/*.sh`, once each, as root) for package
   removals/replacements and distro-neutral config changes. Upstream's
   Arch-specific `omarchy-migrate` is intentionally not run (see
   `fedora/migrations/README.md`).
6. Validate — `install.sh --update` reports package + CLI wiring + version

Steps 3-4 require the development checkout. For a purely end-user install (no
git checkout), the Omarchy userspace itself is not yet auto-updated by `dnf`;
see "Limitations" below.

### Limitations

- The Omarchy **userspace** (the `/usr/share/omarchy` tree) is a rolling branch
  (`quattro`), not a versioned release. `omarchy update` keeps it current in two
  ways: `git subtree pull` from a checkout with an `upstream` remote, or — as a
  fallback for non-git/remote-less checkouts — a direct download of the
  `quattro` tarball rsynced into `/usr/share/omarchy` (see
  `omarchy_fedora_sync_userspace_tarball` in `update.sh`). Both paths then
  re-apply wiring via `install.sh --update`. Packaging the userspace as an RPM
  is intentionally avoided: a static RPM would drift immediately against the
  rolling branch; a live fetch has no staleness window.
- The upstream `omarchy-update` flow is pacman/AUR-specific (`pacman -Syu`,
  `paccache`, `yay`, `pacman-key`); those steps have no Fedora equivalent and
  are replaced by `dnf upgrade` + the first-party COPR RPMs.
