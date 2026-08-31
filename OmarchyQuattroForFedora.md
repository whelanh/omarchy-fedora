# Project Specification: Omarchy Quattro for Fedora

## 0. Mission

Develop a Fedora implementation of **Omarchy Quattro** whose primary design goal is:

> Provide the Omarchy Quattro desktop experience on Fedora while keeping the Fedora-specific code as a thin compatibility layer that can continuously track upstream `omacom/omarchy` Quattro with minimal merge conflict.

The project must NOT become an independent fork containing duplicated copies of the Omarchy desktop implementation.

The desired architecture is:

```text
                    omacom/omarchy
                         |
                      quattro
                         |
                         v
                Upstream Quattro
                         |
             +-----------+-----------+
             |                       |
           Arch                    Fedora
             |                       |
          pacman/AUR             dnf/RPM/COPR
             |                       |
             +-----------+-----------+
                         |
                   Same Omarchy
                  desktop/config
```

The Fedora layer should primarily solve:

- package acquisition
- package naming differences
- repository/COPR configuration
- Fedora-specific system configuration
- Fedora-specific initramfs/system integration
- Fedora-specific installation/bootstrap
- Fedora-specific testing
- incompatibilities that cannot reasonably be eliminated from upstream

Everything else should remain upstream Omarchy code whenever practical.

---

# 1. Authoritative upstream

The authoritative upstream repository is:

https://github.com/omacom/omarchy

The target branch is currently:

```text
quattro
```

Do not assume that `main` is the correct source for this project.

At the beginning of every development session:

```bash
git fetch upstream
git log --oneline --decorate -20 upstream/quattro
```

Determine whether upstream has changed before modifying the Fedora layer.

The upstream repository is MIT licensed. Preserve all upstream copyright/license information.

---

# 2. Development philosophy

## 2.1 Do not fork-and-diverge

Do NOT solve problems by copying entire upstream directories into a Fedora-specific implementation.

Avoid creating:

```text
fedora/config/
fedora/themes/
fedora/shell/
fedora/applications/
```

containing duplicated Omarchy code.

Prefer:

```text
fedora/
    packages/
    system/
    distro/
    patches/
    tests/
```

plus minimal modifications to upstream files where an abstraction is genuinely needed.

## 2.2 Minimize permanent patches

Every change to upstream code must be classified as one of:

1. Fedora-only and therefore appropriate for the Fedora layer.
2. Distro-independent improvement that should be proposed upstream.
3. Temporary compatibility patch that should eventually disappear.

If a change benefits both Arch and Fedora, strongly prefer preparing an upstream pull request rather than maintaining a Fedora-only patch.

## 2.3 Never blindly translate commands

Do not mechanically replace:

```text
pacman → dnf
```

Instead identify the semantic operation:

```text
install package
remove package
query package
upgrade system
enable repository
install package file
build package
detect package
```

and implement a package-manager abstraction.

---

# 3. Repository architecture

Create a new repository, tentatively named:

```text
omarchy-fedora
```

Do not initially create a complete standalone fork of Omarchy.

The repository should contain approximately:

```text
omarchy-fedora/
├── README.md
├── LICENSE
├── ARCHITECTURE.md
├── UPSTREAM.md
├── COMPATIBILITY.md
├── CONTRIBUTING.md
│
├── fedora/
│   ├── packages/
│   │   ├── base.txt
│   │   ├── desktop.txt
│   │   ├── applications.txt
│   │   └── optional.txt
│   │
│   ├── mappings/
│   │   ├── packages.yaml
│   │   └── repositories.yaml
│   │
│   ├── system/
│   │   ├── systemd/
│   │   ├── sysctl/
│   │   ├── udev/
│   │   └── dracut/
│   │
│   ├── scripts/
│   │   ├── bootstrap.sh
│   │   ├── install.sh
│   │   ├── update.sh
│   │   └── uninstall.sh
│   │
│   └── tests/
│
├── patches/
│   └── README.md
│
└── .github/
    └── workflows/
        ├── upstream-sync.yml
        ├── fedora-build.yml
        └── integration-test.yml
```

The exact structure may change after analysis of upstream Quattro.

Do not create unnecessary abstraction merely for aesthetic reasons.

---

# 4. Phase 1 — Repository reconnaissance

Before writing implementation code, perform a complete analysis of upstream Quattro.

Clone:

```bash
git clone https://github.com/omacom/omarchy.git
cd omarchy
git checkout quattro
```

Add:

```bash
git remote add upstream https://github.com/omacom/omarchy.git
```

Create a machine-readable inventory.

Search all files for:

```text
pacman
pacman-key
makepkg
PKGBUILD
AUR
paru
yay
Arch
archlinux
/etc/pacman
pacman.conf
mkinitcpio
linux-headers
pkgctl
systemd
systemctl
dnf
rpm
flatpak
yay
paru
```

Also search for:

```text
apt
zypper
brew
nix
```

to identify existing abstraction or cross-distro logic.

Search shell scripts for package-manager operations rather than merely searching for the string `pacman`.

Examples:

```bash
grep -RInE 'pacman|makepkg|paru|yay|PKGBUILD|mkinitcpio' .
```

Also inspect:

```text
install/
bin/
etc/
config/
default/
migrations/
shell/
applications/
test/
```

and any package manifests.

The current upstream repository contains separate areas for installation, migrations, shell, applications, configuration, themes, and tests; preserve those upstream boundaries rather than flattening them.

Produce:

```text
docs/ARCH_SPECIFIC_INVENTORY.md
```

containing a table:

| File | Operation | Arch assumption | Fedora equivalent | Proposed solution | Upstream change? |
|---|---|---|---|---|---|

Do not proceed to large-scale implementation until this inventory is complete.

---

# 5. Phase 2 — Classify dependencies

Create a complete list of packages required by Quattro.

For every package, determine:

```text
Upstream package
Fedora package
Repository
Status
Notes
```

Use the following classifications:

```text
FEDORA_OFFICIAL
FEDORA_COPR
FEDORA_RPM_EXTERNAL
FLATPAK
BUILD_FROM_SOURCE
NOT_AVAILABLE
NOT_REQUIRED
FEDORA_SUBSTITUTE
```

Example:

```yaml
ripgrep:
  fedora:
    package: ripgrep
    source: FEDORA_OFFICIAL

some-arch-package:
  fedora:
    package: some-fedora-package
    source: FEDORA_SUBSTITUTE
```

Do not assume that identical package names imply identical functionality.

Verify packages with:

```bash
dnf info PACKAGE
dnf repoquery PACKAGE
dnf provides PATH_OR_COMMAND
```

where appropriate.

---

# 6. Phase 3 — Build the package abstraction

Implement a Fedora package backend.

The semantic API should support at minimum:

```bash
omarchy_pkg_install
omarchy_pkg_remove
omarchy_pkg_update
omarchy_pkg_upgrade
omarchy_pkg_is_installed
omarchy_pkg_install_file
omarchy_pkg_enable_repo
omarchy_pkg_query
```

Do not expose `dnf` directly throughout Omarchy scripts.

For example, instead of:

```bash
dnf install foo
```

use:

```bash
omarchy_pkg_install foo
```

The Fedora implementation may internally call:

```bash
dnf install -y foo
```

The abstraction must:

- use noninteractive mode where appropriate
- fail safely
- preserve useful error output
- handle already-installed packages
- handle unavailable packages
- distinguish package-not-found from transaction failure
- support root/sudo execution correctly
- avoid unnecessary package-manager invocations

---

# 7. Phase 4 — Package mapping

Create a declarative Fedora package mapping.

Preferred format:

```yaml
packages:
  ripgrep:
    package: ripgrep
    source: fedora

  example-arch-package:
    package: example-fedora-package
    source: fedora

  example-aur-package:
    package: example-package
    source: copr
    repository: owner/project
```

The mapping must not silently substitute unrelated software.

Every substitution requires a comment explaining compatibility.

For packages unavailable on Fedora:

1. Search Fedora repositories.
2. Search COPR.
3. Search Flathub if it is a GUI application.
4. Determine whether upstream source can be built.
5. Only then mark unavailable.

Produce:

```text
COMPATIBILITY.md
```

with the complete package status.

---

# 8. Phase 5 — Repository/COPR management

Implement explicit repository management.

Do not blindly add random COPR repositories.

Each external repository must document:

- owner
- repository
- packages supplied
- why Fedora official repositories are insufficient
- trust/security considerations
- whether it is mandatory or optional

Prefer Fedora official packages whenever functionally adequate.

The installer must detect whether a repository is already enabled before attempting to add it.

---

# 9. Phase 6 — Identify system-level incompatibilities

Analyze every upstream system-level operation.

Pay particular attention to:

```text
kernel
initramfs
bootloader
dracut
mkinitcpio
SELinux
sysctl
udev
systemd
NetworkManager
Bluetooth
PipeWire
polkit
seat/session management
graphics stack
GPU firmware
display manager/login
```

Do not disable SELinux merely to make something work.

If an Omarchy operation assumes Arch's `mkinitcpio`, determine the correct Fedora mechanism, normally involving `dracut`.

Document every difference in:

```text
fedora/system/
COMPATIBILITY.md
```

---

# 10. Phase 7 — Create the Fedora installer

The first deliverable is NOT an ISO.

The first deliverable is:

```bash
./fedora/scripts/install.sh
```

which operates on a supported Fedora installation.

Initial supported target:

```text
Fedora Workstation / Fedora minimal installation
x86_64
systemd
Wayland-capable hardware
```

Do not initially attempt to support:

- Fedora Atomic variants
- Silverblue
- Kinoite
- Asahi
- ARM
- immutable Fedora variants

unless they are specifically added later.

The installer must:

1. Verify Fedora.
2. Verify architecture.
3. Verify systemd.
4. Verify network.
5. Verify sudo access.
6. Verify sufficient disk space.
7. Install required Fedora repositories.
8. Install required packages.
9. Install/configure Omarchy.
10. Configure system services.
11. Configure user files.
12. Validate installation.
13. Provide a clear reboot instruction.

The installer must be idempotent.

Running it twice should not corrupt the system.

---

# 11. Phase 8 — Upstream integration model

The most important architectural requirement is that upstream Quattro remains authoritative.

Use one of these two models:

### Preferred model

Vendor upstream through a Git subtree or equivalent mechanism, while keeping Fedora code separate.

OR:

### Acceptable model

Maintain a thin fork with:

```text
upstream/quattro
fedora
```

where `fedora` contains only Fedora-specific changes.

The agent must evaluate both and select the method that produces the smallest long-term maintenance burden.

Do NOT copy upstream files manually.

---

# 12. Upstream synchronization

Implement an automated synchronization process.

At minimum:

```bash
git fetch upstream
git diff fedora..upstream/quattro
```

must allow maintainers to determine exactly what upstream changed.

Create:

```text
.github/workflows/upstream-sync.yml
```

The workflow should periodically:

1. Fetch upstream Quattro.
2. Determine whether upstream has changed.
3. Attempt to integrate the new upstream state.
4. Run static tests.
5. Build/install the Fedora implementation in CI where practical.
6. Report failures.
7. Open or update an issue/PR when manual intervention is required.

Never automatically deploy a broken upstream version to users.

---

# 13. Upstream change classification

Whenever synchronization detects changes, classify them:

```text
SAFE
FEDORA_RELEVANT
CONFLICT
NEW_DEPENDENCY
REMOVED_DEPENDENCY
SYSTEM_INTEGRATION_CHANGE
MANUAL_REVIEW_REQUIRED
```

Examples:

### Safe

Upstream modifies:

```text
themes/
```

and no Fedora-specific patch touches that area.

Merge automatically.

### Fedora relevant

Upstream adds a new package.

Update:

```text
fedora/mappings/packages.yaml
```

and test.

### Conflict

Upstream modifies a file containing a Fedora compatibility patch.

Stop automatic merge and request manual review.

### System integration change

Upstream changes:

```text
initramfs
systemd
boot
GPU
session
```

Require explicit integration testing.

---

# 14. Prevent Fedora patches from spreading

Every Fedora-specific modification must be recorded in:

```text
patches/README.md
```

with:

```text
Patch:
Reason:
Affected upstream files:
Can this be upstreamed?:
Upstream issue/PR:
Expected removal condition:
```

If a patch becomes unnecessary because upstream adopts an abstraction, remove it.

The project should continually shrink its patch set.

---

# 15. Prefer upstreamable abstractions

When an upstream Omarchy script currently contains:

```bash
pacman ...
```

and the correct solution is to introduce a distro-neutral function, consider implementing that abstraction upstream.

For example:

```bash
omarchy_pkg_install
```

should ideally become an Omarchy-level abstraction if it can benefit multiple distributions.

The Fedora project should then consume the upstream abstraction rather than carrying its own version indefinitely.

This is the single most important technique for long-term synchronization.

---

# 16. Testing strategy

Testing must occur in disposable Fedora VMs before testing physical hardware.

Create a VM test matrix:

```text
Fedora version:
  current stable
  previous supported stable

Architecture:
  x86_64

Desktop:
  Wayland
  Hyprland
```

At minimum test:

### Installation

```text
fresh Fedora
→ installer
→ reboot
→ Hyprland
```

### Core functionality

Verify:

- login
- Hyprland starts
- terminal opens
- application launcher
- Omarchy menu
- keybindings
- notifications
- audio
- networking
- Bluetooth
- screen lock
- suspend/resume
- screenshots
- clipboard
- browser
- file manager
- themes
- wallpaper
- status bar
- Quickshell components
- Omarchy CLI

### Package operations

Verify:

```text
install
remove
update
upgrade
query
```

### Recovery

Verify:

- installer rerun
- interrupted installation
- missing package
- disabled COPR
- network failure
- reboot during installation

---

# 17. Golden VM

Create a reproducible Fedora VM specifically for integration testing.

The development workflow should be:

```text
modify Fedora layer
       ↓
build/test
       ↓
destroy VM
       ↓
fresh Fedora VM
       ↓
install
       ↓
automated tests
```

Do not use the developer's daily Fedora/Omarchy system as the primary integration environment.

---

# 18. Quattro feature compatibility matrix

Create:

```text
QUATTRO_FEATURES.md
```

with:

| Feature | Upstream Quattro | Fedora | Status | Notes |
|---|---|---|---|---|
| Hyprland | yes | yes | PASS | |
| Quickshell | yes | yes | PASS | |
| Omarchy CLI | yes | | | |
| Themes | yes | | | |
| Web apps | yes | | | |
| Notifications | yes | | | |
| Audio | yes | | | |
| Bluetooth | yes | | | |
| Screenshots | yes | | | |
| System updates | yes | | | |
| Snapshots | yes | | | |

The target is feature parity, not merely "Hyprland starts."

---

# 19. Do not create an ISO initially

Do NOT build a Fedora ISO until:

```text
Fedora installer works
AND
Quattro feature compatibility is high
AND
upstream synchronization works
AND
automated VM testing works
```

Only then investigate:

```text
Fedora custom image
Fedora bootable container/image
Fedora kickstart
Fedora spin
```

The installer is the MVP.

---

# 20. Update mechanism for end users

The Fedora implementation should provide a clear update operation.

Conceptually:

```bash
omarchy-update
```

should perform:

```text
1. Fetch Fedora repository metadata
2. Update Fedora packages
3. Check upstream Omarchy Quattro version
4. Update the Omarchy userspace
5. Run required migrations
6. Validate installation
```

Do not update the system by blindly doing:

```bash
git pull
```

on a live installation.

The update mechanism must understand:

```text
current upstream commit
target upstream commit
required migrations
Fedora package changes
```

---

# 21. Version tracking

Maintain a small state file containing:

```yaml
upstream:
  repository: https://github.com/omacom/omarchy.git
  branch: quattro
  commit: <commit>

fedora:
  compatibility_version: <version>
```

The installation should be able to report:

```text
Omarchy Fedora
Fedora: 43
Omarchy upstream: <commit>
Fedora compatibility layer: <version>
```

This makes support and debugging substantially easier.

---

# 22. Migration handling

Whenever upstream introduces a migration, determine whether it is distro-neutral.

If it is:

```text
consume upstream migration
```

If it is Fedora-specific:

```text
fedora/migrations/
```

Do not duplicate upstream migrations unnecessarily.

---

# 23. Security requirements

Never solve compatibility problems by:

```text
disabling SELinux
disabling systemd security
running everything as root
chmod 777
disabling firewall
adding arbitrary repositories
```

Every external repository must be explicitly documented.

All downloaded scripts must be reviewed before execution.

Do not pipe untrusted remote content directly into:

```bash
bash
sh
```

without validation.

---

# 24. Documentation

The finished project must document:

```text
README.md
INSTALLATION.md
UPDATING.md
ARCHITECTURE.md
COMPATIBILITY.md
TROUBLESHOOTING.md
UPSTREAM.md
QUATTRO_FEATURES.md
```

The README must clearly state:

> This is a Fedora compatibility implementation of Omarchy Quattro. The upstream Omarchy repository remains authoritative for the desktop experience.

---

# 25. Relationship to existing projects

Study, but do not blindly copy, these projects:

## Upstream Omarchy

https://github.com/omacom/omarchy

This is the authoritative source.

## Omarchy Mac Fedora

https://github.com/omarchy-mac/omarchy-mac-fedora

Study particularly:

- Fedora package handling
- Fedora bootstrap
- update mechanism
- Fedora-specific system handling
- compatibility documentation

This project currently targets Fedora Asahi/aarch64 and explicitly does not support ordinary x86_64 Fedora, so use it as an architectural reference rather than as the implementation target.

## Omadora

https://github.com/matoval/omadora

Study it for historical Fedora adaptation decisions.

Do NOT simply fork it as the foundation of this project.

Its fork-based architecture is useful as a reference but does not satisfy the primary requirement of maintaining close synchronization with modern upstream Quattro.

---

# 26. Development phases

Execute the project in this order.

## Phase 1 — Reconnaissance

Deliver:

```text
ARCH_SPECIFIC_INVENTORY.md
PACKAGE_MAPPING.md
ARCHITECTURE.md
```

No major implementation yet.

## Phase 2 — Fedora package layer

Implement:

```text
package abstraction
package mappings
COPR handling
repository management
```

Deliver a script capable of installing the complete dependency set.

## Phase 3 — Bootstrap

Implement:

```text
fedora/scripts/bootstrap.sh
fedora/scripts/install.sh
```

Get a fresh Fedora VM to a bootable Hyprland desktop.

## Phase 4 — Quattro integration

Integrate:

```text
config
themes
applications
shell
bin
migrations
```

from upstream rather than copying them.

## Phase 5 — System integration

Implement Fedora equivalents for:

```text
initramfs
system services
udev
sysctl
graphics/session integration
```

## Phase 6 — Feature testing

Complete:

```text
QUATTRO_FEATURES.md
```

and get core functionality passing.

## Phase 7 — Upstream synchronization

Implement:

```text
upstream-sync.yml
```

and demonstrate that an upstream Quattro change can be incorporated without manually copying the whole repository.

## Phase 8 — Automated integration testing

Create disposable Fedora VM tests.

## Phase 9 — End-user updater

Implement reliable Omarchy/Fedora update handling.

## Phase 10 — Optional image/ISO

Only after the previous phases are stable.

---

# 27. Definition of done

The project is NOT complete merely because Hyprland starts.

The project is complete when:

1. A fresh supported Fedora installation can be converted to Omarchy Quattro using one documented procedure.
2. The resulting system provides the major Quattro functionality.
3. Fedora packages are obtained through a documented package abstraction.
4. Fedora-specific code is isolated.
5. Upstream Quattro remains the authoritative source for the desktop/configuration code.
6. An upstream Quattro update can be detected automatically.
7. Most upstream changes merge without manual modification.
8. Fedora-specific conflicts are automatically identified.
9. The entire installation can be tested in a disposable VM.
10. End users have a reliable update mechanism.
11. The project contains no unnecessary duplicated upstream code.
12. Fedora-specific patches are documented and, where appropriate, proposed upstream.
13. The system does not require disabling Fedora security mechanisms.
14. The installer is idempotent and recoverable.

---

# 28. Agent operating rules

While executing this project:

### Rule 1

Do not make large speculative changes.

### Rule 2

Before modifying upstream-derived code, determine whether the change can instead be implemented in the Fedora compatibility layer.

### Rule 3

Before creating a Fedora-specific patch, determine whether the correct solution should be contributed upstream.

### Rule 4

Never assume an Arch package has a Fedora equivalent. Verify it.

### Rule 5

Never assume an Arch system operation has a Fedora equivalent. Investigate its semantics.

### Rule 6

Do not use the user's production Omarchy system as a test target.

### Rule 7

Use a disposable VM for destructive testing.

### Rule 8

After every major phase, commit working code.

### Rule 9

Keep commits small and logically separated.

Prefer commits such as:

```text
Add Fedora package abstraction
Add Fedora package mappings
Add Fedora COPR support
Add Fedora bootstrap
Add Fedora system integration
Add Quattro integration tests
Add upstream synchronization
```

rather than one enormous commit.

### Rule 10

At the end of each phase, update the documentation and report:

```text
Completed:
Remaining:
Known incompatibilities:
Upstream dependencies:
Fedora-specific patches:
Tests passed:
Tests failed:
```

---

# 29. Final architectural objective

The ideal final repository should make this possible:

```text
              NEW UPSTREAM QUATTRO COMMIT
                         |
                         v
                automated detection
                         |
                         v
                Fedora compatibility
                    test/build
                         |
              +----------+----------+
              |                     |
            PASS                  FAIL
              |                     |
              v                     v
        update Fedora         create issue/
          compatibility       require review
```

The long-term goal is not to maintain "another Omarchy."

The goal is to maintain:

> **a Fedora adapter for Omarchy Quattro.**

The smaller that adapter becomes, the more successful the project is.