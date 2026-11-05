#!/usr/bin/env bash
# Snapper orphan-metadata detection, shared by update.sh.
#
# snapper only keeps a snapshot in its list when /.snapshots/<num>/snapshot is
# a btrfs subvolume root (st_ino == 256, a directory). If a deletion, rollback
# or interrupted cleanup removes the subvolume but leaves info.xml behind,
# snapper logs "snapshot check failed. not adding snapshot <num>" on every
# operation and never lists or cleans that number again. These are metadata-only
# leftovers; after confirming with `btrfs subvolume show`, removing the whole
# /.snapshots/<num> directory is safe.
#
# Takes the snapshots root as $1 (default /.snapshots) so tests can point it at
# a fixture. Prints one orphaned snapshot number per line.

omarchy_snapshot_orphans() {
  local dir="${1:-/.snapshots}"
  local d out ino type

  for d in "$dir"/[0-9]*; do
    # No info.xml means no snapper metadata to clean up.
    [ -e "$d/info.xml" ] || continue

    ino= type=
    if out="$(stat -c '%i %F' "$d/snapshot" 2>/dev/null)"; then
      ino="${out%% *}"
      type="${out#* }"
    fi

    # Mirrors snapper's Btrfs::checkSnapshot(): st_ino == 256 && S_ISDIR.
    if [ "$ino" != 256 ] || [ "$type" != directory ]; then
      printf '%s\n' "${d##*/}"
    fi
  done
}
