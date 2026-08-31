# Omarchy Quattro - omacalc (calculator)
# Upstream: https://github.com/omacom/omacalc  (Qt6, qmake6)
# %OT VERIFY: confirm the release tag/version, the binary name and install
# path produced by `./bin/build` (qmake6 + make), and the .desktop file name.
Name:           omacalc
Version:        0.1.0
Release:        1%{?dist}
Summary:        Omarchy calculator

License:        MIT
URL:            https://github.com/omacom/omacalc
Source0:        %{url}/archive/refs/heads/master.tar.gz

BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
# qmake6 ships in qt6-qtbase-devel (or qt6-qttools-devel)
Requires:       hicolor-icon-theme

%description
Omacalc is a fast, native calculator built with Qt6 for the Omarchy desktop.

%prep
%autosetup -n %{name}-master

%build
# Upstream provides ./bin/build (qmake6 .pro + make). Prefer qmake directly.
qmake6 %{name}.pro
%make_build

%install
%make_install

%files
%license LICENSE
%{_bindir}/%{name}
%{_datadir}/applications/*.desktop
%{_datadir}/icons/hicolor/*/*/*.* 2>/dev/null || true

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Scaffold SPEC for Fedora (PENDING-VERIFY: not yet built in mock)
