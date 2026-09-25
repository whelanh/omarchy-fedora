# Omarchy Quattro - owe (Omarchy Wallpaper Engine)
# Upstream: https://github.com/omacom/owe (C, meson)
# Source-built from the same tag archive as owe-lockfeed; this SPEC mirrors the
# Arch `owe` package (daemon + CLI + renderer + hooks), not the qml-plugin.
Name:           owe
Version:        0.2.7
Release:        1%{?dist}
Summary:        High-performance wallpaper engine for Omarchy (mp4, gif, stills)

# Upstream ships no LICENSE file; the project is MIT (meson.build `license`).
License:        MIT
URL:            https://github.com/omacom/owe
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  gcc
BuildRequires:  pkgconf
BuildRequires:  wayland-devel
BuildRequires:  wayland-protocols-devel
BuildRequires:  libglvnd-devel
BuildRequires:  libepoxy-devel
BuildRequires:  mpv-devel
BuildRequires:  ffmpeg-free-devel
BuildRequires:  systemd-devel
BuildRequires:  python3

Requires:       mpv
Requires:       ffmpeg-free
Requires:       socat

%description
OWE (Omarchy Wallpaper Engine) renders high-performance desktop video
backgrounds (mp4, gif, stills) and feeds the lock screen its frames. This
package ships the owe CLI, the owed daemon and owe-render helper, the owed
systemd user unit, and the theme-set sync hook.

%prep
%autosetup -n %{name}-%{version}

%build
%meson
%meson_build

%install
%meson_install
# The upstream user unit points at ~/.local/bin/owed (its source install);
# ship it with the packaged path instead.
install -d %{buildroot}%{_userunitdir}
sed 's|%h/.local/bin/owed|%{_bindir}/owed|' systemd/owed.service \
  > %{buildroot}%{_userunitdir}/owed.service
install -Dm755 hooks/owe-idle %{buildroot}%{_bindir}/owe-idle
install -Dm644 hooks/theme-set.d/10-owe-sync %{buildroot}%{_datadir}/owe/10-owe-sync
install -Dm644 config/config.toml %{buildroot}%{_docdir}/%{name}/config.toml.example

%files
%{_bindir}/owe
%{_bindir}/owed
%{_bindir}/owe-render
%{_bindir}/owe-idle
%{_datadir}/owe/10-owe-sync
%{_userunitdir}/owed.service
%{_docdir}/%{name}/config.toml.example

%changelog
* Fri Sep 25 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.7-1
- Automatic update to upstream v0.2.7

* Mon Sep 21 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.2-1
- Initial Fedora package: OWE wallpaper engine (meson build, v0.2.2)
