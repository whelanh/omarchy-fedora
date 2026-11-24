# Omarchy Quattro - omaview (picture viewer and media player)
# Upstream: https://github.com/omacom/omaview (Qt6/CMake, MIT)
#
# Omaview replaced imv and mpv in omarchy-base.packages (upstream 9599f7661,
# "Replace imv and mpv with Omaview"): default/applications/mimeapps.list points
# every picture, video and song type at omaview.desktop, and the old imv/mpv
# launchers are gone. Upstream's Arch pkgbuild (omacom/omarchy-pkgs) is the
# reference for the dependency set; there is no Fedora package, so the port
# builds it from source.
#
# Qt 6's FFmpeg multimedia backend is built into Fedora's qt6-qtmultimedia
# (Arch splits it out as qt6-multimedia-ffmpeg), so there is no separate
# BuildRequires/Requires for the backend. kimageformats (HEIC, AVIF, JPEG XL)
# is upstream's optdepends and maps to a Recommends here: pictures in those
# formats simply do not decode without it.
%global debug_package %{nil}

Name:           omaview
Version:        0.1.2
Release:        1%{?dist}
Summary:        Omarchy's picture viewer and media player

License:        MIT
URL:            https://github.com/omacom/omaview
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  pkgconf-pkg-config
BuildRequires:  qt6-qtbase-devel
# qpa/qplatformnativeinterface.h: the only private Qt header (a window's
# wl_surface, for idle inhibition). The call is a virtual call, not a link
# against Qt's private symbols, so the package is not tied to one Qt version.
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
BuildRequires:  wayland-devel
BuildRequires:  wayland-protocols-devel

Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtimageformats
Requires:       qt6-qtmultimedia
Requires:       qt6-qtsvg
Requires:       qt6-qtwayland
Requires:       wl-clipboard
Requires:       xdg-desktop-portal
# Either FFmpeg build provides the binary: RPM Fusion's full ffmpeg Conflicts
# with Fedora's ffmpeg-free, so require the file, not one of the packages.
Requires:       /usr/bin/ffmpeg

Recommends:     kf6-kimageformats
Recommends:     cups-libs

%description
Omaview is Omarchy's picture viewer and media player: pictures (including
animated WebP) with EXIF orientation and an info card, and video and music
through Qt Multimedia, with playlists, chapters, subtitles, MPRIS and media
keys. It is the default handler for every picture, video and song type in
Omarchy's mimeapps.list.

Packetized pictures need the optional kimageformats plugins; install
kf6-kimageformats for HEIC, AVIF and JPEG XL.

%prep
%autosetup -n %{name}-%{version}

%build
# Build the app target, not upstream's test binaries: the package ships the
# viewer, and the tests are upstream CI's job. Keeping them out of the RPM
# build also means a Qt test-API churn (the kind that broke omacut 0.8.3 on Qt
# 6.11) cannot hold back a working viewer.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target %{name} -j"$(nproc)"

%install
install -Dm755 build/%{name} %{buildroot}%{_bindir}/%{name}
install -Dm644 share/omaview.desktop \
    %{buildroot}%{_datadir}/applications/omaview.desktop
install -Dm644 share/omaview.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/omaview.svg
install -Dm644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md

%files
%license LICENSE
%{_bindir}/omaview
%{_datadir}/applications/omaview.desktop
%{_datadir}/icons/hicolor/scalable/apps/omaview.svg
%{_datadir}/doc/%{name}/README.md

%changelog
* Tue Nov 24 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.2-1
- Automatic update to upstream v0.1.2

* Tue Nov 17 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.1-1
- Automatic update to upstream v0.1.1

* Mon Nov 16 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Initial Fedora package (v0.1.0): Omarchy's picture viewer and media player,
  which replaces imv and mpv in omarchy-base.packages
