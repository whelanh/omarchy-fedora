# Omarchy Quattro - omawrite (markdown editor)
# Upstream: https://github.com/omacom/omawrite  (Qt6, qmake6)
# %OT VERIFY: confirm release tag/version, binary name, and the .desktop file.
Name:           omawrite
Version:        0.1.0
Release:        1%{?dist}
Summary:        Omarchy markdown editor

License:        MIT
URL:            https://github.com/omacom/omawrite
Source0:        %{url}/archive/refs/heads/master.tar.gz

BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtquickcontrols2-devel
Requires:       hicolor-icon-theme

%description
Omawrite is a clean, focused Qt6 markdown editor built for the Omarchy desktop.

%prep
%autosetup -n %{name}-master

%build
qmake6 %{name}.pro
%make_build

%install
%make_install

%files
%license LICENSE
%{_bindir}/%{name}
%{_datadir}/applications/*.desktop

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Scaffold SPEC for Fedora (PENDING-VERIFY: not yet built in mock)
