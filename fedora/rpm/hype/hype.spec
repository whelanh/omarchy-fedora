# Omarchy Quattro - hype (Markdown presentations with a visual slide editor)
# Upstream: https://github.com/omacom/hype (C++/Qt6, qmake6)
# Verified against upstream pkgbuild/PKGBUILD + bin/build (v0.5.0). The app
# shells out to `source-highlight` (code blocks) and `ffmpeg` (video/animated
# media export), and links zlib + libwebp for image compression. v0.5.0 adds
# Qt SVG to the project.
%global debug_package %{nil}

Name:           hype
Version:        0.7.1
Release:        1%{?dist}
Summary:        Simple Markdown presentations with a visual slide editor

License:        MIT
URL:            https://github.com/omacom/hype
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
BuildRequires:  qt6-qtsvg-devel
BuildRequires:  libwebp-devel
BuildRequires:  zlib-devel

Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       qt6-qtimageformats
Requires:       qt6-qtsvg
Requires:       libwebp
Requires:       source-highlight
Requires:       ffmpeg-free
Requires:       hicolor-icon-theme
Requires:       xdg-desktop-portal

%description
Hype is a native Omarchy app for simple presentations written in Markdown.
It offers a visual slide editor, images and video, theme-aware rendering, and
export to PDF or PowerPoint.

%prep
%autosetup -n %{name}-%{version}

%build
./bin/build

%install
install -Dm755 build/hype %{buildroot}%{_bindir}/hype
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm644 pkgbuild/hype.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/hype.svg
install -Dm644 pkgbuild/hype.desktop %{buildroot}%{_datadir}/applications/hype.desktop
install -Dm644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md

%files
%license LICENSE
%{_bindir}/hype
%{_datadir}/icons/hicolor/scalable/apps/hype.svg
%{_datadir}/applications/hype.desktop
%{_datadir}/doc/%{name}/README.md

%changelog
* Thu Nov 12 2026 whelanh <brickhousedevelopers@gmail.com> - 0.7.1-1
- Automatic update to upstream v0.7.1

* Thu Oct 15 2026 whelanh <brickhousedevelopers@gmail.com> - 0.6.0-1
- Automatic update to upstream v0.6.0

* Wed Oct 14 2026 whelanh <brickhousedevelopers@gmail.com> - 0.5.0-2
- Add BuildRequires: qt6-qtsvg-devel (v0.5.0 builds with `QT += svg`)

* Wed Oct 14 2026 whelanh <brickhousedevelopers@gmail.com> - 0.5.0-1
- Automatic update to upstream v0.5.0

* Mon Sep 28 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.3-1
- Initial Fedora package: Markdown presentation editor (v0.4.3)
