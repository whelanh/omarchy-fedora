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
# Checked against upstream v0.5.0: bin/build drives CMake, QML is compiled into
# the binary through src/resources.qrc, and the desktop entry and icon ship
# in-tree under share/ (v0.2.0 had them under pkgbuild/). The only linked
# libraries beyond Qt are glib/gio (pkgconfig gio-2.0, gio-unix-2.0) and zlib;
# archives are made by exec'ing bsdtar (Fedora's own package), and 0.5.0 added
# the xdg-desktop-portal FileChooser backend and the bundled plugins.
%global debug_package %{nil}

Name:           omarchy-folio
Version:        0.5.0
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

Requires:       bsdtar
Requires:       glib2
Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       qt6-qtsvg
Requires:       qt6-qtwayland
Requires:       xdg-utils

# Upstream optdepends: previews, remote places and sharing are dlopened or
# exec'd at runtime, so none of them may be hard requirements.
Recommends:     ffmpegthumbnailer
Recommends:     glycin-loaders
Recommends:     gvfs
Recommends:     jq
Recommends:     poppler-utils
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

Since 0.5.0 it also offers `folio chooser`, an xdg-desktop-portal FileChooser
backend, so other applications' Open and Save dialogs are Folio's; and it runs
plugins, the bundled Tailscale, Dropbox and LocalSend ones included.

%prep
# The upstream tarball unpacks as folio-<version>, not <name>-<version>.
%autosetup -n folio-%{version}

%build
# Build the app target, not upstream's folio_tests: 0.5.0's tests call
# QDragEnterEvent's QPointF overload, which Qt 6.11 (Fedora 44/45) does not
# have, and the tests are upstream CI's job. The same reason omacut and
# omaview build only their app target.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target folio -j"$(nproc)"

%install
install -Dm755 build/folio %{buildroot}%{_bindir}/folio
install -Dm644 share/folio.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/folio.svg
install -Dm644 share/folio.desktop \
    %{buildroot}%{_datadir}/applications/folio.desktop
# 0.5.0: the Open and Save dialog backend other apps reach through
# xdg-desktop-portal (D-Bus starts `folio chooser` on demand), hidden from the
# launcher.
install -Dm644 share/folio.portal \
    %{buildroot}%{_datadir}/xdg-desktop-portal/portals/folio.portal
install -Dm644 share/org.freedesktop.impl.portal.desktop.folio.service \
    %{buildroot}%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.folio.service
install -Dm644 share/folio-chooser.desktop \
    %{buildroot}%{_datadir}/applications/folio-chooser.desktop
# 0.5.0: the bundled plugins (Tailscale, Dropbox, LocalSend), keeping the
# commands executable - Folio runs them and reads their JSON.
install -d %{buildroot}%{_datadir}/folio/plugins
cp -a plugins/. %{buildroot}%{_datadir}/folio/plugins/
install -Dm644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md
install -Dm644 docs/plugins.md %{buildroot}%{_datadir}/doc/%{name}/plugins.md

%files
%license LICENSE
%{_bindir}/folio
%{_datadir}/applications/folio.desktop
%{_datadir}/applications/folio-chooser.desktop
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.folio.service
%{_datadir}/folio
%{_datadir}/icons/hicolor/scalable/apps/folio.svg
%{_datadir}/xdg-desktop-portal/portals/folio.portal
%{_datadir}/doc/%{name}/README.md
%{_datadir}/doc/%{name}/plugins.md

%changelog
* Tue Nov 17 2026 whelanh <brickhousedevelopers@gmail.com> - 0.5.0-1
- Automatic update to upstream v0.5.0

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
