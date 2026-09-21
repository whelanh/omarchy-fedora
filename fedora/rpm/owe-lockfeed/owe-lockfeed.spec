# Omarchy Quattro - owe-lockfeed (OWE lock screen video feed QML module)
# Upstream: https://github.com/omacom/owe (C++/Qt6, cmake)
# Built from the same tag archive as `owe`; this SPEC packages only the
# qml-plugin/ subtree, mirroring Omarchy's separate `owe-lockfeed` package.
Name:           owe-lockfeed
Version:        0.2.2
Release:        1%{?dist}
Summary:        Lock screen video feed module for the OWE wallpaper engine

# Upstream ships no LICENSE file; the project is MIT (meson.build `license`).
License:        MIT
URL:            https://github.com/omacom/owe
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  qt6-qtdeclarative-devel

Requires:       qt6-qtdeclarative

%description
OWE lock feed is the Qt6 QML module (Owe.LockFeed) that lets the Omarchy lock
screen render frames produced by the owe wallpaper engine.

%prep
%autosetup -n owe-%{version}

%build
# BUILD_TESTING=OFF skips the Qt6::Test target, which would otherwise need a
# display and Qt Test at build time.
cmake -S qml-plugin -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DCMAKE_INSTALL_LIBDIR=%{_lib} \
  -DBUILD_TESTING=OFF
cmake --build build --verbose

%install
DESTDIR=%{buildroot} cmake --install build

%files
%{_libdir}/qt6/qml/Owe/LockFeed/

%changelog
* Mon Sep 21 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.2-1
- Initial Fedora package: OWE lock feed QML module (v0.2.2)
