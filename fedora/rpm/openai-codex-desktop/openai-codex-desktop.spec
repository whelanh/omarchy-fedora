# Omarchy Quattro - openai-codex-desktop (official ChatGPT desktop app)
# Upstream: OpenAI's own Debian release, repacked the way Omarchy does it
# (omacom/omarchy-pkgs pkgbuilds/openai-codex-desktop). Proprietary; the
# /usr/bin entry is replaced with Omarchy's flags-aware launcher. Loaded by the
# SUPER+SPACE Install > AI > ChatGPT Desktop row. Install-on-demand.
%global debug_package %{nil}
# /usr/lib/chatgpt bundles its own Electron runtime plus private libraries
# (including Qt shims, a musl/NDK toolchain and libvips). Keep those out of the
# RPM dependency namespace; system libraries stay explicitly required below.
%global __provides_exclude ^lib(EGL|GLESv2|ffmpeg|vk_swiftshader|vulkan|qt.*_shim|vips.*|log|c.._shared)\.so
%global __requires_exclude ^((lib(EGL|GLESv2|ffmpeg|vk_swiftshader|vulkan|qt.*_shim|vips.*|log|c.._shared)\.so|libc\.musl.*|libc\.so($|[^.])|libdl\.so($|[^.])|libm\.so($|[^.])|libpthread\.so($|[^.])|libgcc_s\.so($|[^.]))|/usr/bin/(node|pwsh)$)
# The bundled Electron/Qt tree carries libraries built on other toolchains whose
# versioned symbols (GCC_3.5, GLIBC_2.17, CXXABI_ARM_1.3.3, ...) no Fedora
# package provides, which yields unsatisfiable auto-Requires. Skip auto-Requires
# from the bundled tree; the system libraries the app needs are required below.
%global __requires_exclude_from ^/usr/lib/chatgpt/.*$

Name:           openai-codex-desktop
Version:        26.1111.71704
Release:        1%{?dist}
Summary:        Official ChatGPT desktop app with Codex

License:        LicenseRef-proprietary
URL:            https://chatgpt.com/codex/
Source0:        https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_%{version}_amd64.deb#/%{name}-%{version}.deb
Source1:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/0cda54605912bd3526d34f970411593a34a0ead8/pkgbuilds/openai-codex-desktop/chatgpt-launcher.sh

ExclusiveArch:  x86_64
Provides:       chatgpt = %{version}-%{release}
Provides:       codex-desktop = %{version}-%{release}
Conflicts:      chatgpt

BuildRequires:  binutils
BuildRequires:  xz

Requires:       alsa-lib
Requires:       at-spi2-core
Requires:       cairo
Requires:       cups-libs
Requires:       dbus-libs
Requires:       expat
Requires:       gdk-pixbuf2
Requires:       glib2
Requires:       glibc
Requires:       gtk3
Requires:       hicolor-icon-theme
Requires:       libX11
Requires:       libXcomposite
Requires:       libXdamage
Requires:       libXext
Requires:       libXfixes
Requires:       libXrandr
Requires:       libdrm
Requires:       libgcc
Requires:       libnotify
Requires:       libusb1
Requires:       libxcb
Requires:       libxkbcommon
Requires:       mesa-libEGL
Requires:       mesa-libgbm
Requires:       nspr
Requires:       nss
Requires:       openssl-libs
Requires:       pango
Requires:       systemd-libs
Requires:       xdg-utils
Requires:       xz-libs

%description
Official ChatGPT desktop app with Codex. This package repacks OpenAI's Debian
release, keeping its bundled Electron runtime and replacing the Debian
/usr/bin entry with the flags-aware launcher from the upstream Omarchy package,
mirroring the upstream PKGBUILD. Installed on demand from the ChatGPT Desktop
entry in the Omarchy menu.

%prep
# Upstream ships a Debian package, not a tarball, so there is no top directory
# to autosetup; the data payload is unpacked with ar + tar.
%setup -q -c -T -n %{name}-%{version}
ar p "%{SOURCE0}" data.tar.xz | tar -xJf -

%build
:

%install
# Install verbatim from the unpacked payload, mirroring the upstream PKGBUILD
# (which keeps the deb's AppArmor profile).
cp -a etc usr %{buildroot}/
rm -f %{buildroot}/usr/bin/chatgpt
install -D -m 0755 "%{SOURCE1}" %{buildroot}%{_bindir}/chatgpt
ln -s chatgpt %{buildroot}%{_bindir}/codex-desktop
# Move the Debian copyright to the Fedora license dir.
install -D -m 0644 %{buildroot}%{_datadir}/doc/chatgpt/copyright \
  %{buildroot}%{_licensedir}/openai-codex-desktop/copyright
# Debian package-policy files are not used on Fedora.
rm -rf %{buildroot}%{_datadir}/doc %{buildroot}%{_datadir}/lintian
# Use Electron's unprivileged namespace sandbox.
if [ -f %{buildroot}/usr/lib/chatgpt/chrome-sandbox ]; then
  chmod 0755 %{buildroot}/usr/lib/chatgpt/chrome-sandbox
fi

%files
%license %{_licensedir}/openai-codex-desktop/copyright
%config(noreplace) /etc/apparmor.d/chatgpt
/usr/lib/chatgpt
%{_bindir}/chatgpt
%{_bindir}/codex-desktop
%{_datadir}/applications/chatgpt.desktop
%{_datadir}/pixmaps/chatgpt.png
%{_datadir}/metainfo/com.openai.chatgpt.metainfo.xml
%{_datadir}/swcatalog/xml/com.openai.chatgpt.xml

%changelog
* Thu Nov 19 2026 whelanh <brickhousedevelopers@gmail.com> - 26.1111.71704-1
- Automatic update to upstream v26.1111.71704

* Wed Nov 18 2026 whelanh <brickhousedevelopers@gmail.com> - 26.1111.71025-1
- Automatic update to upstream v26.1111.71025

* Tue Oct 13 2026 whelanh <brickhousedevelopers@gmail.com> - 26.1007.21434-1
- Initial Fedora package: repack of OpenAI's ChatGPT desktop release
