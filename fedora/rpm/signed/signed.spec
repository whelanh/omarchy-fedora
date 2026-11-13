# Omarchy Quattro - signed (sign PDFs and fill them in)
# Upstream: https://github.com/omacom/signed (Qt6/qmake6, MIT). Native Omarchy
# app: signs PDFs and stamps text/dates, exports via qpdf, file access through
# the desktop portal.
%global debug_package %{nil}

Name:           signed
Version:        0.3.2
Release:        1%{?dist}
Summary:        Sign PDFs and fill them in with text and dates

License:        MIT
URL:            https://github.com/omacom/signed
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  pkgconfig(poppler-qt6)
BuildRequires:  pkgconfig(libqpdf)

Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtwayland
Requires:       poppler-qt6
Requires:       qpdf
Requires:       xdg-desktop-portal
Requires:       hicolor-icon-theme
Requires:       google-noto-sans-fonts

%description
Signed signs PDFs and fills them in with text and dates. It is a native Omarchy
Qt6 application that opens documents through the XDG desktop portal and writes
the stamped result with qpdf.

%prep
%autosetup

%build
./bin/build

%install
install -Dm755 build/signed %{buildroot}%{_bindir}/signed
install -Dm644 pkgbuild/signed.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/signed.svg
install -Dm644 pkgbuild/signed.desktop %{buildroot}%{_datadir}/applications/signed.desktop
install -Dm644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md

%files
%license LICENSE
%doc %{_datadir}/doc/%{name}/README.md
%{_bindir}/signed
%{_datadir}/icons/hicolor/scalable/apps/signed.svg
%{_datadir}/applications/signed.desktop

%changelog
* Thu Nov 12 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.2-1
- Automatic update to upstream v0.3.2

* Thu Oct 15 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.1-1
- Automatic update to upstream v0.3.1

* Wed Oct 14 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.0-1
- Automatic update to upstream v0.2.0

* Sun Oct 11 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Initial Fedora package: Omarchy PDF signing app (v0.1.0)
