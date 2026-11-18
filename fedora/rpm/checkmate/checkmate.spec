# Omarchy Quattro - checkmate (3D chess)
# Upstream: https://github.com/omacom/checkmate (Qt6/CMake, MIT)
#
# Upstream added Checkmate to omarchy-base.packages (3489996a2, "Install
# Checkmate by default"), and a migration installs it on existing machines. It
# is Omarchy's own app, so Fedora has no package for it and the COPR builds it
# from source; omacom/omarchy-pkgs is the reference for the dependency set. The
# board and pieces are Qt Quick 3D (qt6-qtquick3d), and the window icon goes
# through Qt's SVG icon engine (qt6-qtsvg).
#
# Upstream's CMakeLists looks for xvfb-run with find_program(... REQUIRED) at
# configure time, before any target is built, so the Xvfb package is a build
# requirement even though we build only the game target and never the tests.
%global debug_package %{nil}

Name:           checkmate
Version:        0.1.3
Release:        1%{?dist}
Summary:        Native 3D chess for one or two players

License:        MIT
URL:            https://github.com/omacom/checkmate
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtquick3d-devel
BuildRequires:  xorg-x11-server-Xvfb

Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtquick3d
Requires:       qt6-qtsvg
Requires:       qt6-qtwayland

%description
Checkmate is Omarchy's own 3D chess game: original piece sets in four scenes
(orbital, atelier, candy and woodland), local play for one or two players, and
a computer opponent. You start it from the launcher, where it is listed as
Chess; press ? inside it for every shortcut.

It is installed by default from Omarchy's base package list.

%prep
%autosetup -n %{name}-%{version}

%build
# The version string comes from the tarball's directory name
# (checkmate-<version>), so the package reports v%{version} rather than a git
# describe from a checkout.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target %{name} -j"$(nproc)"

%install
install -Dm755 build/%{name} %{buildroot}%{_bindir}/%{name}
install -Dm644 share/checkmate.desktop \
    %{buildroot}%{_datadir}/applications/checkmate.desktop
install -Dm644 share/checkmate.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/checkmate.svg
install -Dm644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md

%files
%license LICENSE
%{_bindir}/checkmate
%{_datadir}/applications/checkmate.desktop
%{_datadir}/icons/hicolor/scalable/apps/checkmate.svg
%{_datadir}/doc/%{name}/README.md

%changelog
* Wed Nov 18 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.3-1
- Automatic update to upstream v0.1.3

* Tue Nov 17 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.2-1
- Initial Fedora package (v0.1.2): Omarchy's 3D chess game, installed by
  default from omarchy-base.packages
