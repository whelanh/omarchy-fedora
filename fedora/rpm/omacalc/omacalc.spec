# Omarchy Quattro - omacalc (calculator)
# Upstream: https://github.com/omacom/omacalc (Qt6/qmake6)
# Verified against upstream bin/build + source tree (v0.2.2). No desktop/icon
# is shipped upstream; this is the bare Qt6 binary + license.
%global debug_package %{nil}

Name:           omacalc
Version:        0.2.2
Release:        1%{?dist}
Summary:        A fast, native calculator built with Qt 6 for the Omarchy desktop

License:        MIT
URL:            https://github.com/omacom/omacalc
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz
# Desktop entry + icon are AUR-side files maintained in omacom/omarchy-pkgs.
Source1:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/master/pkgbuilds/omacalc/omacalc.desktop
Source2:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/master/pkgbuilds/omacalc/omacalc.svg

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       hicolor-icon-theme
Requires:       xdg-desktop-portal

%description
Omacalc is a fast, native calculator built with Qt Quick for the Omarchy
desktop.

%prep
%autosetup -n %{name}-%{version}

%build
./bin/build

%install
install -Dm755 build/omacalc %{buildroot}%{_bindir}/omacalc
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm644 fonts/OFL.txt %{buildroot}%{_datadir}/licenses/%{name}/OFL.txt
install -Dm644 %{SOURCE2} %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/omacalc.svg
install -Dm644 %{SOURCE1} %{buildroot}%{_datadir}/applications/omacalc.desktop

%files
%license LICENSE
%{_datadir}/licenses/%{name}/OFL.txt
%{_bindir}/omacalc
%{_datadir}/icons/hicolor/scalable/apps/omacalc.svg
%{_datadir}/applications/omacalc.desktop

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.2-1
- Verified build in Fedora Rawhide container (v0.2.2)
