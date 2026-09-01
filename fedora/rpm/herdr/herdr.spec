# Omarchy Quattro - herdr (terminal workspace manager for AI agents)
# Upstream: https://github.com/herdrdev/herdr (Rust)
%global debug_package %{nil}
# Repack of the upstream release binary (herdr-linux-x86_64). The Arch PKGBUILD
# compiles with a pinned Zig 0.15.2 linker; Fedora cannot rebuild that cleanly,
# so shipping the release assets mirrors the same end result without the
# vendored Zig toolchain.
Name:           herdr
Version:        0.8.2
Release:        1%{?dist}
Summary:        Herdr terminal workspace manager for AI coding agents

License:        Apache-2.0
URL:            https://github.com/herdrdev/herdr
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz
Source1:        %{url}/releases/download/v%{version}/herdr-linux-x86_64

BuildArch:      x86_64

Requires:       gcc-libs
Requires:       glibc

Provides:       omarchy-herdr
Obsoletes:      omarchy-herdr

%description
Herdr manages ephemeral terminal workspaces for AI coding agents.

%prep
%autosetup -n %{name}-%{version}

%install
install -Dm755 %{SOURCE1} %{buildroot}%{_bindir}/herdr
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%files
%license LICENSE
%{_bindir}/herdr

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.8.2-1
- Repack of upstream prebuilt release (v0.8.2); avoids the pinned Zig 0.15.2 toolchain