# Omarchy Quattro - monologue (theme-synced webcam recorder)
# Upstream: https://github.com/omacom/monologue (C++/Qt6, qmake6)
# Verified against upstream pkgbuild/PKGBUILD + bin/build (v0.3.0). Qt6
# Multimedia (FFmpeg backend) for capture and libpulse for metering; the app
# shells out to `ffmpeg`/`ffprobe` to finalize and probe takes.
%global debug_package %{nil}

Name:           monologue
Version:        0.3.0
Release:        1%{?dist}
Summary:        Simple, theme-synced webcam recorder for Omarchy

License:        MIT
URL:            https://github.com/omacom/monologue
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  pkgconf-pkg-config
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
BuildRequires:  pulseaudio-libs-devel

Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       pulseaudio-libs
Requires:       ffmpeg-free
Requires:       hicolor-icon-theme
Requires:       xdg-desktop-portal

%description
Monologue is a simple webcam recorder for Omarchy. It remembers your camera and
microphone, records with one key, syncs with the active Omarchy theme, and
opens finished takes in a built-in editor for trimming and cutting.

%prep
%autosetup -n %{name}-%{version}

%build
./bin/build

%install
install -Dm755 build/monologue %{buildroot}%{_bindir}/monologue
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm644 pkgbuild/monologue.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/monologue.svg
install -Dm644 pkgbuild/monologue.desktop %{buildroot}%{_datadir}/applications/monologue.desktop

%files
%license LICENSE
%{_bindir}/monologue
%{_datadir}/icons/hicolor/scalable/apps/monologue.svg
%{_datadir}/applications/monologue.desktop

%changelog
* Mon Sep 28 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.0-1
- Initial Fedora package: theme-synced webcam recorder (v0.3.0)
