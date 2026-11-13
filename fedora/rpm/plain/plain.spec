# Omarchy Quattro - plain (text editor for config files)
# Upstream: https://github.com/omacom/plain (Qt6/qmake6, MIT).
#
# Omarchy's default editor for config and text files: default/applications/
# mimeapps.list points text/plain (and the config-ish types) at plain.desktop,
# bin/omarchy-default-editor installs it with `omarchy-pkg-add plain`, and
# bin/omarchy-launch-editor falls back to it. Plain is not in Fedora or Arch,
# so the Fedora port packages it first-party.
#
# Checked against upstream v0.2.0 (bin/build + pkgbuild/PKGBUILD): qmake6 build,
# QML compiled in through src/resources.qrc, desktop entry and icon shipped
# in-tree under pkgbuild/. The file picker goes through xdg-desktop-portal over
# D-Bus, so no GTK dependency.
%global debug_package %{nil}

Name:           plain
Version:        0.3.3
Release:        1%{?dist}
Summary:        Omarchy's text editor for config files

License:        MIT
URL:            https://github.com/omacom/plain
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel

Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtwayland
Requires:       xdg-desktop-portal

%description
Plain is Omarchy's small text editor for configuration files: syntax
highlighting, theme-aware colours and a portal-based file picker, with no
project-model or plugin machinery. It is the fallback editor behind Omarchy's
"plain" editor choice and the handler for text/plain and config file types.

%prep
%autosetup -n %{name}-%{version}

%build
./bin/build

%install
install -Dm755 build/plain %{buildroot}%{_bindir}/plain
install -Dm644 pkgbuild/plain.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/plain.svg
install -Dm644 pkgbuild/plain.desktop \
    %{buildroot}%{_datadir}/applications/plain.desktop

%files
%license LICENSE
%{_bindir}/plain
%{_datadir}/icons/hicolor/scalable/apps/plain.svg
%{_datadir}/applications/plain.desktop

%changelog
* Thu Nov 12 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.3-1
- Automatic update to upstream v0.3.3

* Wed Nov 11 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.0-1
- Initial Fedora package (v0.2.0): Omarchy's config-file editor
