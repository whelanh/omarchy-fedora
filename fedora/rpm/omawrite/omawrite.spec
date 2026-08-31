# Omarchy Quattro - omawrite (markdown editor)
# Upstream: https://github.com/omacom/omawrite (Qt6/qmake6)
# Verified against upstream pkgbuild/PKGBUILD + bin/build (v0.5.0).
%global debug_package %{nil}

Name:           omawrite
Version:        0.5.0
Release:        1%{?dist}
Summary:        Dead-simple Markdown writing app built with Qt Quick

License:        MIT
URL:            https://github.com/omacom/omawrite
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       xdg-desktop-portal

%description
Omawrite is a dead-simple Markdown writing app built with Qt Quick for the
Omarchy desktop.

%prep
%autosetup -n %{name}-%{version}

%build
./bin/build

%install
install -Dm755 build/omawrite %{buildroot}%{_bindir}/omawrite
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -Dm644 fonts/OFL.txt %{buildroot}%{_datadir}/licenses/%{name}/OFL.txt
install -Dm644 pkgbuild/omawrite.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/omawrite.svg
install -Dm644 pkgbuild/omawrite.desktop %{buildroot}%{_datadir}/applications/omawrite.desktop

%files
%license LICENSE
%{_datadir}/licenses/%{name}/OFL.txt
%{_bindir}/omawrite
%{_datadir}/icons/hicolor/scalable/apps/omawrite.svg
%{_datadir}/applications/omawrite.desktop

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.5.0-1
- Verified build in Fedora Rawhide container (v0.5.0)
