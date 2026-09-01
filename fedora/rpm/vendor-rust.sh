#!/usr/bin/env bash
# Vendor Rust (crates.io) dependencies into a tarball so an SRPM can build
# OFFLINE inside COPR/mock (their build chroots have no network access). This
# is sourced by build-rpm-in-ci.sh and copr/submit-builds.sh, both of which run
# on a networked host and have already downloaded the spec's Source archives.
#
# Usage: source this file, then:
#   generate_rust_vendor <spec> <sources_dir> [work_dir]
#
# If the spec declares a Source whose name ends in `-vendor.tar.xz`, this runs
# `cargo vendor` against the extracted upstream source and writes
# `<name>-<version>-vendor.tar.xz` into <sources_dir> (containing vendor/ and a
# .cargo/config.toml pointing cargo at it). Requires network + cargo.

generate_rust_vendor() {
  local spec="$1" sources="$2" work="${3:-/tmp/omarchy-vendor}"

  # Only specs that opt in with a `-vendor.tar.xz` Source need this.
  grep -q -- '-vendor.tar.xz' "$spec" || return 0

  local name version
  name="$(python3 - "$spec" <<'PY'
import re,sys
print(re.search(r'^Name:\s*(\S+)', open(sys.argv[1]).read(), re.M).group(1))
PY
)"
  version="$(python3 - "$spec" <<'PY'
import re,sys
print(re.search(r'^Version:\s*(\S+)', open(sys.argv[1]).read(), re.M).group(1))
PY
)"

  local out="$sources/${name}-${version}-vendor.tar.xz"
  [ -f "$out" ] && { echo "vendor: $out already present"; return 0; }

  # The upstream github source archive is fetched as v<version>.tar.gz.
  local src="$sources/v${version}.tar.gz"
  [ -f "$src" ] || { echo "vendor: upstream source archive not found: $src" >&2; return 1; }

  command -v cargo >/dev/null 2>&1 || { echo "vendor: cargo not found (needed to vendor Rust deps)" >&2; return 1; }

  echo "== vendoring Rust deps for $name-$version =="
  rm -rf "$work"; mkdir -p "$work"
  tar xzf "$src" -C "$work"
  local srcdir="$work/$name-$version"
  [ -d "$srcdir" ] || srcdir="$(find "$work" -maxdepth 1 -mindepth 1 -type d | head -1)"
  (
    cd "$srcdir"
    cargo vendor vendor/ >/dev/null \
      && mkdir -p .cargo \
      && printf '%s\n' \
          '[source.crates-io]' \
          'replace-with = "vendored-sources"' \
          '' \
          '[source.vendored-sources]' \
          'directory = "vendor"' \
          > .cargo/config.toml
  ) || { echo "vendor: cargo vendor failed for $name" >&2; return 1; }

  tar cJf "$out" -C "$srcdir" vendor .cargo
  echo "vendor: wrote $out"
}
