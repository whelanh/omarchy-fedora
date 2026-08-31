# Testing Omarchy Quattro on a Fedora VirtManager VM

This guide walks through validating the Fedora compatibility layer on a Fedora
VM you already have in VirtManager (`virt-manager`). It covers:

1. Preparing the VM
2. The static test suite (no system changes)
3. The full installer (`fedora/scripts/install.sh`)
4. The Omarchy CLI wiring (`omarchy-*` on PATH)
5. Building and installing the verified first-party RPMs
6. Cleanup / uninstall

> **Prereq:** a Fedora VM (ideally Rawhide, matching the CI build target —
> the verified RPMs are `fc46`), x86_64, with network access.

---

## 1. Prepare the VM

Take a snapshot before making changes so you can roll back:

```
virt-manager -> select the VM -> Virtual Machine -> Take Snapshot
```

Update the VM and install git:

```sh
sudo dnf -y upgrade --refresh
sudo dnf -y install git
```

Confirm the release (target is Rawhide / recent stable):

```sh
cat /etc/fedora-release
```

---

## 2. Static test suite (safe, no changes)

```sh
git clone https://github.com/whelanh/omarchy-fedora.git
cd omarchy-fedora
bash fedora/tests/static.sh
```

Expected output ends with:

```
== Result: 185 passed, 0 failed ==
```

This validates shell syntax, YAML parsing, the resolver, upstream-package
mapping coverage, and the first-party RPM scaffold (manifest ↔ SPEC ↔
changelog dates). It makes no changes to the system.

---

## 3. Run the installer

First a dry run (checks prerequisites, makes no changes):

```sh
sudo ./fedora/scripts/install.sh --dry-run
```

Then the real install:

```sh
sudo ./fedora/scripts/install.sh
```

Useful flags (see the header of `fedora/scripts/install.sh`):

| Flag            | Effect                                             |
|-----------------|----------------------------------------------------|
| `--dry-run`     | Check prerequisites only; make no changes          |
| `--no-omarchy`  | Install deps/system only; skip the desktop tree    |
| `--user USER`   | Configure user files for `USER`                    |
| `--nvidia`      | Enable NVIDIA handling                             |

What it does: enables the Hyprland COPR and friends, installs
`fedora/packages/{base,desktop}.txt`, drops systemd/sysctl/udev/dracut configs,
copies the vendored upstream tree to `/usr/share/omarchy`, wires the
`omarchy-*` commands onto PATH, and installs `/etc/profile.d/omarchy.sh`.

It is **idempotent** — safe to re-run.

---

## 4. Verify the Omarchy CLI wiring

```sh
which omarchy                                   # -> /usr/bin/omarchy
ls -l /usr/bin/omarchy-* | head                 # symlinks -> /usr/share/omarchy/bin/
cat /etc/profile.d/omarchy.sh                   # sources env-bootstrap
```

In a fresh login shell:

```sh
bash -lc 'echo $OMARCHY_PATH'                   # -> /usr/share/omarchy
omarchy --help
```

**Note:** `omarchy plugin enable/disable` talk to the running shell via
`omarchy-shell shell enablePlugin`, so they require a live Hyprland/Omarchy
desktop session — they will not work from a bare SSH/tty.

---

## 5. Build and install the verified first-party RPMs

The five verified packages (`omacalc`, `omacut`, `omawrite`, `ttfx`, `try`)
build cleanly in a Fedora Rawhide container. Two ways to build them:

### 5a. Directly in the VM

```sh
sudo dnf -y install rpm-build dnf-plugins-core python3-pyyaml
sudo bash fedora/rpm/build-rpm-in-ci.sh
```

This builds each `status: verified` SPEC from `fedora/rpm/manifest.yaml` and
prints `OK: <pkg> built` for each.

### 5b. On the host via podman/docker (mirrors CI)

```sh
bash fedora/rpm/build-in-container.sh omacalc    # single package
```

Requires `podman` or `docker` on the host and network to pull `fedora:rawhide`.

### Install and smoke-test one binary

```sh
sudo dnf -y install /tmp/rpmbuild-omacalc/RPMS/x86_64/omacalc-*.rpm
omacalc --help
```

(Repeat with `omacut`, `omawrite`, `ttfx`, `try` — adjust the RPM path per
package; `try` installs as `/usr/bin/try`.)

### Install all five at once

After building with `build-rpm-in-ci.sh` (step 5a), install every verified RPM
in one shot:

```sh
sudo bash fedora/rpm/install-rpms.sh
```

It locates each `status: verified` package's built `.rpm` under
`/tmp/rpmbuild-<pkg>` (or a base dir you pass as the first argument), installs
them via `dnf`, and prints a smoke-test pass/fail for each binary. Packages
whose RPM is missing are skipped with a warning.

---

## 6. Cleanup / uninstall

```sh
sudo ./fedora/scripts/uninstall.sh
```

To return to a pristine state, roll back to the snapshot taken in step 1.

---

## Known gotchas

- `dnf builddep` and the installer need network (COPR/rpmfusion reachable).
- The Qt/gem specs set `%global debug_package %{nil}` to avoid an rpmbuild
  empty-`debugsourcefiles.list` quirk.
- `ttfx` uses explicit `cargo build --release` rather than Fedora's
  `%cargo_build`, because a plain `rpmbuild` environment lacks the `rpm` cargo
  profile. This is intended and matches CI.
- The 8 `blocked` packages (see `fedora/rpm/README.md`) are skipped by the
  build helpers; they need toolchain/repack/assembly work first.
