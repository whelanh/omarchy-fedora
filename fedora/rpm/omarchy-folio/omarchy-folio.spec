# Omarchy Quattro - folio (Files: the file manager)
# Upstream: https://github.com/omacom/folio (Qt6/CMake, MIT).
#
# Omarchy replaced Nautilus with Folio ("Files"): default/applications/
# mimeapps.list points inode/directory at folio.desktop, and upstream migration
# 1794330979.sh installs folio and drops nautilus, nautilus-python and sushi.
# Folio is not in Fedora or Arch, so the Fedora port packages it first-party.
#
# The RPM is named omarchy-folio, not folio: Fedora has shipped its own package
# called `folio` (Toolstack's markdown note-taking app, versioned 26.x) since
# F45, so an RPM named `folio` either loses dnf's version comparison or shadows
# an unrelated application. The *file* names stay upstream's, because
# bin/omarchy-launch-files runs `folio` and mimeapps points at folio.desktop.
# Obsoletes: folio < 1 replaces only our own earlier 0.4.0 COPR build, never
# Fedora's 26.x package (which this must not touch).
#
# Checked against upstream v0.4.0: bin/build drives CMake, QML is compiled into
# the binary through src/resources.qrc, and the desktop entry and icon ship
# in-tree under share/ (v0.2.0 had them under pkgbuild/). The only linked
# libraries beyond Qt are glib/gio (pkgconfig gio-2.0, gio-unix-2.0) and zlib.
%global debug_package %{nil}

Name:           omarchy-folio
Version:        0.4.0
Release:        1%{?dist}
Summary:        Files: Omarchy's quiet, keyboard-first file manager

License:        MIT
URL:            https://github.com/omacom/folio
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

Obsoletes:      folio < 1
BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  glib2-devel
BuildRequires:  zlib-devel
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel

Requires:       glib2
Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtwayland
Requires:       xdg-utils

# Upstream optdepends: previews, remote places and sharing are dlopened or
# exec'd at runtime, so none of them may be hard requirements.
Recommends:     ffmpegthumbnailer
Recommends:     gvfs
Recommends:     qt6-qtimageformats
Recommends:     qt6-qtpdf
Recommends:     xdg-terminal-exec
Suggests:       dropbox-cli
Suggests:       localsend
Suggests:       tailscale

%description
Folio is Omarchy's file manager, presented as "Files": a quiet, keyboard-first
browser for local folders, mounts and remote places that follows the desktop
theme. It handles inode/directory in Omarchy in place of Nautilus.

%prep
# The upstream tarball unpacks as folio-<version>, not <name>-<version>.
%autosetup -n folio-%{version}

%build
./bin/build

%install
install -Dm755 build/folio %{buildroot}%{_bindir}/folio
install -Dm644 share/folio.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/folio.svg
install -Dm644 share/folio.desktop \
    %{buildroot}%{_datadir}/applications/folio.desktop

%files
%license LICENSE
%{_bindir}/folio
%{_datadir}/icons/hicolor/scalable/apps/folio.svg
%{_datadir}/applications/folio.desktop

%changelog
* Fri Nov 13 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-1
- Rename the RPM to omarchy-folio: Fedora ships an unrelated `folio` package
  (Toolstack's note-taking app, 26.x), so `dnf install folio` installed that
  and never our file manager. File names stay upstream's (/usr/bin/folio,
  folio.desktop); Obsoletes: folio < 1 only replaces our old 0.4.0 build.

* Fri Nov 13 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-2
- Follow upstream's 0.4.0 layout: the desktop entry and icon moved from
  pkgbuild/ to share/, and bin/build now drives CMake
- Declare the CMake build requirement explicitly

* Thu Nov 12 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-1
- Automatic update to upstream v0.4.0

* Wed Nov 11 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.0-1
- Initial Fedora package (v0.2.0): Omarchy's Files app, replacing Nautilus
