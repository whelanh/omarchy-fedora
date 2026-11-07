# Omarchy Quattro - omarchy-hyprland-titlebars (Hyprland titlebars plugin)
# Upstream: https://github.com/omacom/omarchy-hyprland-titlebars (fork of
# hyprwm/hyprland-plugins' hyprbars; BSD-3-Clause AND MIT). A native Hyprland
# plugin loaded from the fixed path
# /usr/lib/omarchy-hyprland-titlebars/titlebars.so; registers as `hyprbars`.
#
# NOTE: like upstream (rebuild_on: hyprland), this plugin is compiled against a
# specific Hyprland build and must be rebuilt whenever Hyprland changes. The
# COPR build pulls hyprland-devel from the nett00n/hyprland per-chroot repo.
%global debug_package %{nil}
%global _lto_cflags %{nil}

Name:           omarchy-hyprland-titlebars
Version:        0.3.0
Release:        3%{?dist}
Summary:        Titlebars for Omarchy's floating workspace mode

License:        BSD-3-Clause AND MIT
URL:            https://github.com/omacom/omarchy-hyprland-titlebars
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
# 0.3.0 moved to Hyprland 0.57 internals; an older hyprland-devel fails here
# with a clear dependency error instead of a missing-header compile error.
BuildRequires:  pkgconfig(hyprland) >= 0.57
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  pkgconfig(libinput)
BuildRequires:  pkgconfig(libudev)
BuildRequires:  pkgconfig(pixman-1)
BuildRequires:  pkgconfig(wayland-server)
BuildRequires:  pkgconfig(xkbcommon)

Requires:       hyprland
Requires:       hyprlang
Requires:       hyprutils

ExclusiveArch:  x86_64

%description
A native Hyprland plugin that gives Omarchy's floating workspace mode its window
titlebars. It is loaded from the fixed path
/usr/lib/omarchy-hyprland-titlebars/titlebars.so and registers with Hyprland as
`hyprbars`. It must match the running Hyprland version and is rebuilt when
Hyprland changes.

%prep
%autosetup

%build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=%{_prefix}
cmake --build build --verbose

%install
DESTDIR=%{buildroot} cmake --install build
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm644 LICENSE.MIT %{buildroot}%{_datadir}/licenses/%{name}/LICENSE.MIT

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%license %{_datadir}/licenses/%{name}/LICENSE.MIT
%{_prefix}/lib/omarchy-hyprland-titlebars/titlebars.so

%changelog
* Sat Nov 7 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.0-3
- Automatic rebuild against hyprland 0.57.1-2 (2026-11-07): native plugin ABI follows its COPR build dependency

* Thu Nov 05 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.0-2
- Rebuild against Hyprland 0.57.1's hyprland-devel (aquamarine 0.16,
  hyprgraphics 0.6) so the plugin ABI hash matches the running compositor.
  The 0.3.0-1 build predated those dependency moves and failed to load with
  "Version mismatch (headers ver is not equal to running hyprland ver)".

* Mon Nov 02 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.0-1
- Automatic update to upstream v0.3.0 (Build against Hyprland 0.57)
- Require pkgconfig(hyprland) >= 0.57: 0.3.0 includes the 0.57 internal headers
  (desktop/view/window/*, desktop/state/WindowState.hpp)

* Tue Oct 13 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.2-1
- Automatic update to upstream v0.2.2

* Sun Oct 11 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.0-1
- Initial Fedora package: Omarchy Hyprland titlebars plugin (v0.2.0)
