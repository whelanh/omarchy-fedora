# Omarchy Quattro - aether (desktop theming / wallpaper colourization)
# Upstream: https://github.com/omacom/aether  (Go + Wails)
# STATUS: BLOCKED (PENDING-VERIFY). Omarchy's own Arch PKGBUILD does NOT
# compile - it installs the prebuilt release binary (aether-linux-amd64) from a
# GitHub release. Building from source needs the Wails toolchain + WebKitGTK,
# which is heavy and fragile in mock. The pragmatic Fedora path is to REPACK the
# upstream release binary, exactly mirroring the PKGBUILD's strategy.
# %OT VERIFY: point Source0 at the exact release asset (tag vX.Y.Z) and confirm
# the asset filename + desktop entry + icon install paths.
Name:           aether
Version:        0.1.0
Release:        1%{?dist}
Summary:        Omarchy wallpaper colour extraction and theming tool

License:        MIT
URL:            https://github.com/omacom/aether
# REPACK: replace with the actual release asset URL once tagged
Source0:        %{url}/releases/download/v%{version}/aether-linux-amd64

Requires:       webkit2gtk4.1
Requires:       gtk3

%description
Aether extracts a colour palette from the current wallpaper and drives Omarchy
theming. STATUS: BLOCKED - scaffold only; verify the release-asset repack.

%prep
# no source build; the release binary is installed directly.
install -m 0755 -D %{SOURCE0} %{buildroot}%{_bindir}/aether

%install
# %install is handled inline above for the no-source repack case.
%{__mkdir_p} %{buildroot}%{_datadir}/applications
cat > %{buildroot}%{_datadir}/applications/aether.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Aether
Exec=aether
Terminal=false
Categories=Utility;Settings;
EOF

%files
%license LICENSE
%{_bindir}/aether
%{_datadir}/applications/aether.desktop

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Scaffold SPEC (BLOCKED: repack of upstream release binary, source build TBD)
