# Omarchy Quattro - qtengine (Qt platform theme)
# Upstream: https://github.com/kossLAN/qtengine (BSD-2-Clause). Omarchy themes
# Qt apps through it: default/hypr/envs.lua sets QT_QPA_PLATFORMTHEME=qtengine,
# config/qtengine/config.json points colorScheme at the theme's rendered
# qtengine.colors, and bin/omarchy-theme-set-qt writes the icon theme into that
# config on every switch.
#
# Not in Fedora official and not in official Arch either (upstream Omarchy takes
# it from the AUR), so it is packaged here instead of enabling a third-party
# COPR for a default-installed component.
#
# Upstream builds Qt5 and Qt6 themes; Omarchy only needs Qt6, so BUILD_QT5=OFF
# drops the qt5-qtbase-private-devel / kf5 devel requirements with it.
#
# NOTE: this is a Qt private-API plugin (Requires libQt6Gui.so.6(Qt_6.x_PRIVATE_API)),
# so it must be rebuilt when Fedora bumps the Qt6 minor version.
%global debug_package %{nil}
%global _lto_cflags %{nil}

# qtpaths6 --query QT_INSTALL_PLUGINS. Set explicitly instead of relying on
# qt6-rpm-macros so the build does not depend on that macro package.
%global qt6_plugindir %{_libdir}/qt6/plugins

Name:           qtengine
Version:        0.2.4
Release:        1%{?dist}
Summary:        Qt platform theme driven by a KDE color scheme

License:        BSD-2-Clause
URL:            https://github.com/kossLAN/qtengine
Source0:        %{url}/archive/refs/tags/%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-kcolorscheme-devel
BuildRequires:  kf6-kiconthemes-devel

Requires:       qt6-qtbase
Requires:       kf6-kconfig
Requires:       kf6-kcolorscheme
Requires:       kf6-kiconthemes

%description
A Qt platform theme that reads a KDE color scheme, icon theme, widget style and
fonts from a single JSON file. Omarchy enables it with
QT_QPA_PLATFORMTHEME=qtengine and points its colorScheme at the current theme's
qtengine.colors, so Qt apps follow the desktop palette.

%prep
%autosetup

%build
%cmake -G Ninja \
    -DBUILD_QT5=OFF \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DQT6_PLUGINDIR=%{qt6_plugindir}
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_libdir}/libqt6engine-common.so
%{qt6_plugindir}/platformthemes/libqt6engine-plugin.so
%{qt6_plugindir}/styles/libqt6engine-style.so

%changelog
* Tue Nov 10 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.4-1
- Initial Fedora package (Qt6 only): upstream Omarchy uses qtengine for Qt theming
