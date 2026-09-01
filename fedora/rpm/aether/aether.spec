# Omarchy Quattro - aether (desktop theming / wallpaper colourization)
# Upstream: https://github.com/omacom/aether (Go + Wails)
%global debug_package %{nil}
# Repack mirrors the upstream Arch PKGBUILD: the release ships prebuilt
# aether-linux-amd64, so no Wails/WebKitGTK toolchain is needed.
Name:           aether
Version:        4.29.8
Release:        1%{?dist}
Summary:        Desktop theming application - extract colors from wallpapers and apply cohesive themes

License:        MIT
URL:            https://github.com/omacom/aether
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz
Source1:        %{url}/releases/download/v%{version}/aether-linux-amd64

BuildArch:      x86_64

Requires:       webkit2gtk4.1
Requires:       gtk3

%description
Aether is a desktop theming application. It extracts a colour palette from the
current wallpaper and applies it as a cohesive theme across the Omarchy
desktop.

%prep
%autosetup -n %{name}-%{version}

%install
install -Dm755 %{SOURCE1} %{buildroot}%{_bindir}/aether
install -Dm644 build/linux/aether.desktop %{buildroot}%{_datadir}/applications/aether.desktop
install -Dm644 li.oever.aether.url-handler.desktop %{buildroot}%{_datadir}/applications/li.oever.aether.url-handler.desktop
install -Dm644 icon.png %{buildroot}%{_datadir}/pixmaps/aether.png
install -Dm644 assets/aether-icon-512.png %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/aether.png
install -Dm644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md

%files
%{_bindir}/aether
%{_datadir}/applications/aether.desktop
%{_datadir}/applications/li.oever.aether.url-handler.desktop
%{_datadir}/pixmaps/aether.png
%{_datadir}/icons/hicolor/512x512/apps/aether.png
%{_datadir}/doc/%{name}/README.md

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 4.29.8-1
- Repack of upstream prebuilt release (v4.29.8), mirroring the Arch PKGBUILD