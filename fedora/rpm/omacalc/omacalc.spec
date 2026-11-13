# Omarchy Quattro - omacalc (calculator)
# Upstream: https://github.com/omacom/omacalc (Qt6/qmake6)
# Verified against upstream bin/build + source tree (v0.3.1). Upstream ships the
# desktop entry and icon in-tree under pkgbuild/.
%global debug_package %{nil}

Name:           omacalc
Version:        0.4.2
Release:        1%{?dist}
Summary:        A fast, native calculator built with Qt 6 for the Omarchy desktop

License:        MIT
URL:            https://github.com/omacom/omacalc
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

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
install -Dm644 pkgbuild/omacalc.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/omacalc.svg
install -Dm644 pkgbuild/omacalc.desktop %{buildroot}%{_datadir}/applications/omacalc.desktop

%files
%license LICENSE
%{_datadir}/licenses/%{name}/OFL.txt
%{_bindir}/omacalc
%{_datadir}/icons/hicolor/scalable/apps/omacalc.svg
%{_datadir}/applications/omacalc.desktop

%changelog
* Thu Nov 12 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.2-1
- Automatic update to upstream v0.4.2

* Wed Oct 14 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.1-1
- Automatic update to upstream v0.3.1

* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.2-1
- Verified build in Fedora Rawhide container (v0.2.2)
