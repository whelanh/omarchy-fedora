# Omarchy Quattro - omasnap (screenshot + annotation editor)
# Upstream: https://github.com/tobi/omasnap (C++/Qt6, CMake)
%global debug_package %{nil}
# Built from upstream source. The Arch release tarball is a prebuilt binary
# linked against Arch's Qt 6.12, which no Fedora release provides (F44/45/46
# ship Qt 6.11), so repacking it produces an uninstallable package. Upstream's
# CMake only requires Qt >= 6.8.
Name:           omasnap
Version:        1.24.0
Release:        1%{?dist}
Summary:        Native Wayland screenshot and annotation editor for Omarchy

License:        MIT
URL:            https://github.com/tobi/omasnap
Source0:        %{url}/archive/v%{version}/omasnap-%{version}.tar.gz

Requires:       hyprland
Requires:       layer-shell-qt
Requires:       wl-clipboard
Requires:       qt6-qtbase
Requires:       xdg-utils
Recommends:     tesseract
Suggests:       tesseract-langpack-eng

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  qt6-qtbase-devel
BuildRequires:  layer-shell-qt-devel
BuildRequires:  wayland-devel
BuildRequires:  wayland-protocols-devel
BuildRequires:  libdeflate-devel

%description
Omasnap is a native Wayland screenshot and annotation editor for Omarchy and
Hyprland. It supersedes Satty/Tensaku for the screenshot and imv "edit" flows.

%prep
%setup -q

%build
%cmake -DCMAKE_BUILD_TYPE=Release
%cmake_build

%install
%cmake_install
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/omasnap/LICENSE

%files
%{_bindir}/omasnap
%{_datadir}/applications/omasnap.desktop
%{_datadir}/licenses/omasnap/

%changelog
* Wed Oct 28 2026 whelanh <brickhousedevelopers@gmail.com> - 1.24.0-1
- Automatic update to upstream v1.24.0

* Sun Oct 25 2026 whelanh <brickhousedevelopers@gmail.com> - 1.23.0-1
- Automatic update to upstream v1.23.0

* Sat Oct 24 2026 whelanh <brickhousedevelopers@gmail.com> - 1.22.0-2
- Build from upstream source instead of the prebuilt Arch release tarball
- Fixes an unsatisfiable libQt6Core.so.6(Qt_6.12) requirement: the Arch
  binary is linked against Qt 6.12, while Fedora 44/45/46 ship Qt 6.11

* Sat Oct 24 2026 whelanh <brickhousedevelopers@gmail.com> - 1.22.0-1
- Automatic update to upstream v1.22.0

* Tue Sep 22 2026 whelanh <brickhousedevelopers@gmail.com> - 1.21.0-1
- Initial Fedora package: repack of upstream v1.21.0 Arch x86_64 release
