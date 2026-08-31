# Omarchy Quattro - omacut (video length trimmer)
# Upstream: https://github.com/omacom/omacut (Qt6/qmake6)
# Verified against upstream pkgbuild/PKGBUILD + bin/build (v0.4.0).
%global debug_package %{nil}

Name:           omacut
Version:        0.4.0
Release:        1%{?dist}
Summary:        Dead-simple video length trimmer built with Qt Quick and ffmpeg

License:        MIT
URL:            https://github.com/omacom/omacut
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       ffmpeg
Requires:       xdg-desktop-portal

%description
Omanent is a dead-simple video length trimmer built with Qt Quick and ffmpeg.

%prep
%autosetup -n %{name}-%{version}

%build
./bin/build

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
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-1
- Verified build in Fedora Rawhide container (v0.4.0)
