# Omarchy Quattro - herdr (terminal workspace manager for AI agents)
# Upstream: https://github.com/omacom-io/herdr (fork of herdrdev/herdr)
# STATUS: BLOCKED (PENDING-VERIFY). Rust build that requires a PINNED Zig 0.15.2
# toolchain (used as the resolver/linker via `cargo build --frozen --release`
# with the Zig cc). Fedora does not package that Zig version, so the spec must
# vendor a Zig binary fetch in %prep (as the Arch PKGBUILD does). This is the
# hardest of the 13 to get into a clean mock build.
# %OT VERIFY: pin the exact upstream commit/version and the Zig 0.15.2 fetch
# URL; reproduce the PKGBUILD's vendor/portable-pty patch and build.rs env
# version stamping.
Name:           herdr
Version:        0.8.2
Release:        1%{?dist}
Summary:        Terminal workspace manager for AI agents

License:        Apache-2.0
URL:            https://github.com/omacom-io/herdr
Source0:        %{url}/archive/refs/heads/main.tar.gz

BuildRequires:  rust >= 1.70
BuildRequires:  gcc
Requires:       gcc-libs

%description
Herdr manages ephemeral terminal workspaces for AI coding agents. STATUS:
BLOCKED - requires a pinned Zig toolchain not cleanly packaged in Fedora.

%prep
%autosetup -n %{name}-main
# %OT VERIFY: fetch Zig 0.15.2 into a $PATH prefix (mirrors PKGBUILD) e.g.
#   curl -L <zig archive> | tar -xJ -C %{_builddir}/zig
#   export PATH=%{_builddir}/zig:$PATH
# and export ZIG / ZIG_GLOBAL_CACHE_DIR for cargo.

%build
# %OT VERIFY: cargo build --frozen --release with Zig linker env set.
# cargo build --release --locked --target x86_64-unknown-linux-gnu

%install
# %OT VERIFY: install the built binary to %{_bindir}/herdr.

%files
%license LICENSE
%{_bindir}/herdr

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.8.2-1
- Scaffold SPEC (BLOCKED: pinned Zig toolchain must be vendored first)
