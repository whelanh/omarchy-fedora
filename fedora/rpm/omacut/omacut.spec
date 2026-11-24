# Omarchy Quattro - omacut (video length trimmer)
# Upstream: https://github.com/omacom/omacut (Qt6/CMake)
# Verified against upstream pkgbuild/PKGBUILD + bin/build (v0.4.0).
%global debug_package %{nil}

Name:           omacut
Version:        0.8.4
Release:        1%{?dist}
Summary:        Dead-simple video length trimmer built with Qt Quick and ffmpeg

License:        MIT
URL:            https://github.com/omacom/omacut
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       hicolor-icon-theme
# Either FFmpeg build provides the binaries: RPM Fusion's full ffmpeg Conflicts
# with Fedora's ffmpeg-free, so require the files, not one of the packages.
Requires:       /usr/bin/ffmpeg
Requires:       /usr/bin/ffprobe
Requires:       xdg-desktop-portal

%description
Omanent is a dead-simple video length trimmer built with Qt Quick and ffmpeg.

%prep
%autosetup -n %{name}-%{version}

%build
# Build the app target, not upstream's test binary: v0.8.3's tests pass a
# QPointF to QDragEnterEvent, whose constructor takes QPoint in Qt 6.11
# (Fedora 45), so upstream's ./bin/build fails on the test target alone while
# the app itself compiles. The package ships the app; upstream's CI runs the
# tests.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target omacut -j"$(nproc)"

%install
install -Dm755 build/omacut %{buildroot}%{_bindir}/omacut
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm644 pkgbuild/omacut.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/omacut.svg
install -Dm644 pkgbuild/omacut.desktop %{buildroot}%{_datadir}/applications/omacut.desktop

%files
%license LICENSE
%{_bindir}/omacut
%{_datadir}/icons/hicolor/scalable/apps/omacut.svg
%{_datadir}/applications/omacut.desktop

%changelog
* Tue Nov 24 2026 whelanh <brickhousedevelopers@gmail.com> - 0.8.4-1
- Automatic update to upstream v0.8.4

* Sun Nov 15 2026 whelanh <brickhousedevelopers@gmail.com> - 0.8.3-3
- Build the app target instead of upstream's ./bin/build: v0.8.3's tests pass
  a QPointF to QDragEnterEvent, which takes QPoint in Qt 6.11 (Fedora 45), so
  the test binary no longer compiles while the app does

* Sun Nov 15 2026 whelanh <brickhousedevelopers@gmail.com> - 0.8.3-2
- Require /usr/bin/ffmpeg and /usr/bin/ffprobe instead of the ffmpeg-free
  package: RPM Fusion's full ffmpeg provides the files and Conflicts with
  ffmpeg-free, so the hard package dependency made omacut uninstallable on
  machines that have it

* Thu Nov 12 2026 whelanh <brickhousedevelopers@gmail.com> - 0.8.3-1
- Automatic update to upstream v0.8.3

* Thu Oct 15 2026 whelanh <brickhousedevelopers@gmail.com> - 0.7.2-1
- Automatic update to upstream v0.7.2

* Wed Oct 14 2026 whelanh <brickhousedevelopers@gmail.com> - 0.7.0-1
- Automatic update to upstream v0.7.0

* Sat Oct 3 2026 whelanh <brickhousedevelopers@gmail.com> - 0.5.0-1
- Automatic update to upstream v0.5.0

* Tue Sep 01 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-2
- Require ffmpeg-free (ffmpeg is RPM Fusion-only; not available on stock Fedora)

* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-1
- Verified build in Fedora Rawhide container (v0.4.0)
