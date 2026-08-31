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

The eventual `omarchy-update` equivalent should perform:

1. Fetch Fedora repository metadata (dnf makecache)
2. Update Fedora packages (dnf upgrade)
3. Check upstream Omarchy Quattro version
4. Update the Omarchy userspace
5. Run required migrations
6. Validate installation

Steps 3-6 are not yet implemented; they depend on the first-party RPM
packaging and migration plumbing.
