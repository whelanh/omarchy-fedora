# Omarchy Quattro - cliamp (terminal music player)
# Upstream: https://github.com/bjarneo/cliamp (Go, CGO audio deps)
%global debug_package %{nil}
# Repack of the upstream release binary (cliamp-linux-amd64), mirroring the
# Arch PKGBUILD's package layout. No Go toolchain needed.
Name:           cliamp
Version:        2.0.0
Release:        2%{?dist}
Summary:        A retro terminal music player inspired by Winamp 2.x

License:        MIT
URL:            https://github.com/bjarneo/cliamp
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz
Source1:        %{url}/releases/download/v%{version}/cliamp-linux-amd64

BuildArch:      x86_64

Requires:       alsa-lib
Requires:       ffmpeg-free
Requires:       yt-dlp

%description
Cliamp is a Curses-based command-line music player inspired by Winamp 2.x. It
plays local audio and streams, with ffmpeg/yt-dlp handling remote sources.

%prep
%autosetup -n %{name}-%{version}

%install
install -Dm755 %{SOURCE1} %{buildroot}%{_bindir}/cliamp
install -Dm644 cliamp.desktop %{buildroot}%{_datadir}/applications/cliamp.desktop
install -Dm644 Cliamp.png %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/cliamp.png
install -Dm644 Cliamp.png %{buildroot}%{_datadir}/pixmaps/cliamp.png
install -Dm644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%files
%license LICENSE
%{_bindir}/cliamp
%{_datadir}/applications/cliamp.desktop
%{_datadir}/icons/hicolor/512x512/apps/cliamp.png
%{_datadir}/pixmaps/cliamp.png

%changelog
* Tue Sep 01 2026 whelanh <brickhousedevelopers@gmail.com> - 2.0.0-2
- Use ffmpeg-free (Fedora official) and drop stale CGO deps (flac/libvorbis/libogg not linked)

* Tue Sep 01 2026 whelanh <brickhousedevelopers@gmail.com> - 2.0.0-1
- Update to upstream v2.0.0 (prebuilt cliamp-linux-amd64 repack)

* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 1.63.2-1
- Repack of upstream release binary (v1.63.2), mirroring the Arch PKGBUILD