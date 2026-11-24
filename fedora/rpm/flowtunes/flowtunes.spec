# Omarchy Quattro - flowtunes (endless music with local models)
# Upstream: https://github.com/omacom/flowtunes (Qt6/CMake, MIT)
#
# Upstream added Flowtunes to omarchy-base.packages in d7d69f63d ("Install
# Flowtunes as a default app"); it is Omarchy's own app, so Fedora has no
# package for it and the COPR builds it from source. omacom/omarchy-pkgs is the
# reference for the dependency set, with one Fedora difference: Arch's
# qt6-multimedia links FFmpeg directly, while Fedora builds the GStreamer
# backend, so the plugins that decode the MP3s Flowtunes writes and plays are
# required explicitly.
%global debug_package %{nil}

Name:           flowtunes
Version:        0.4.0
Release:        1%{?dist}
Summary:        Endless music in the genre you pick

License:        MIT
URL:            https://github.com/omacom/flowtunes
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtshadertools-devel

Requires:       /usr/bin/ffmpeg
Requires:       gstreamer1-plugins-base
Requires:       gstreamer1-plugins-good
Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       qt6-qtsvg
Requires:       qt6-qtwayland

%description
Flowtunes plays endless music in the genre you pick, made on your machine by
Omarchy's local music model through omarchy-local-ai. Each tune is saved as an
MP3 in ~/Music/<genre>, tagged with its name and playable in any player.

It is installed by default from Omarchy's base package list and listed in the
launcher as Flowtunes.

%prep
%autosetup -n %{name}-%{version}

%build
# Build the app target, not upstream's test binary: the tests are upstream CI's
# job.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target %{name} -j"$(nproc)"

%install
install -Dm755 build/%{name} %{buildroot}%{_bindir}/%{name}
install -Dm644 share/%{name}.desktop \
    %{buildroot}%{_datadir}/applications/%{name}.desktop
install -Dm644 share/%{name}.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/%{name}.svg

%files
%license LICENSE
%{_bindir}/flowtunes
%{_datadir}/applications/flowtunes.desktop
%{_datadir}/icons/hicolor/scalable/apps/flowtunes.svg

%changelog
* Tue Nov 24 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-1
- Automatic update to upstream v0.4.0

* Mon Nov 23 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.0-1
- Automatic update to upstream v0.3.0

* Sat Nov 21 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.0-1
- Initial Fedora package (v0.2.0): Omarchy's local music app, installed by
  default from omarchy-base.packages (upstream d7d69f63d). Requires the
  GStreamer MP3 decode and audio plugins, because Fedora's qt6-qtmultimedia
  uses the GStreamer backend where Arch's links FFmpeg directly
