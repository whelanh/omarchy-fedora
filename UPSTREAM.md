# UPSTREAM

## Authoritative upstream

- Repository: https://github.com/omacom/omarchy
- Branch: `quattro` (do **not** assume `main`)
- License: MIT

The upstream Omarchy tree is vendored here under [`upstream/`](upstream) as a
squashed git subtree. Upstream remains the authority for the desktop, shell,
themes, config, applications, and CLI.

## Vendored state

| Field | Value |
|---|---|
| Source | `git://github.com/omacom/omarchy.git` |
| Branch | `quattro` |
| Version file | `upstream/version` (`4.0.0.alpha`) |
| Vendored commit | `b686ed89` (first vendor) |

## Synchronization

At the start of each development session, and via the `upstream-sync` GitHub
workflow:

```bash
git fetch upstream
git subtree pull --prefix upstream --squash upstream quattro \
  -m "chore(upstream): sync Omarchy quattro"
git diff fedora..upstream/quattro   # review what changed
```

The `upstream-sync` workflow runs daily. When the pull merges cleanly and the
Fedora layer (`fedora/`) is untouched, it opens a `SAFE` PR. If the pull
conflicts, it opens an issue requiring manual review.

## Classifying upstream changes

- **SAFE** — changes only to areas with no Fedora patch (e.g. `themes/`). Merge.
- **FEDORA_RELEVANT** — new package added. Update `fedora/mappings/packages.yaml`,
  test.
- **CONFLICT** — modifies a file carrying a Fedora patch. Stop, manual review.
- **NEW_DEPENDENCY / REMOVED_DEPENDENCY** — adjust the Fedora package mapping.
- **SYSTEM_INTEGRATION_CHANGE** — initramfs / systemd / boot / GPU / session.
  Requires explicit VM integration testing.
- **MANUAL_REVIEW_REQUIRED** — anything ambiguous.

## Never

- Never manually copy upstream files into `fedora/`.
- Never deploy a broken upstream version automatically.
- Never let `fedora/` drift far enough that `git subtree pull` starts
  conflicting on every run.
