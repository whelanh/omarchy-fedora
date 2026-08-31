# Omarchy Quattro - cliamp (terminal music player)
# Upstream: https://github.com/bjarneo/cliamp  (Go, ~3.9k stars)
# STATUS: BLOCKED (PENDING-VERIFY). Go/CGO build with ALSA audio deps.
# %OT VERIFY: confirm exact -devel package names on Fedora for
# alsa-lib/flac/libvorbis/libogg/mpg123, the build command (go build ./... with
# CGO), and the installed binary name + completion files.
Name:           cliamp
Version:        0.1.0
Release:        1%{?dist}
Summary:        Terminal music player for Omarchy

License:        MIT
URL:            https://github.com/bjarneo/cliamp
Source0:        %{url}/archive/refs/heads/master.tar.gz

BuildRequires:  golang
BuildRequires:  alsa-lib-devel
BuildRequires:  flac-devel
BuildRequires:  libvorbis-devel
BuildRequires:  libogg-devel
BuildRequires:  mpg123-devel
Requires:       ffmpeg
Requires:       yt-dlp

%description
Cliamp is a Curses-based command-line music player. STATUS: BLOCKED - scaffold
only until the Go/CGO build and Fedora libdevel names are verified.

%prep
%autosetup -n %{name}-master
%goprep

%build
CGO_ENABLED=1 %gobuild -o %{_vpath_builddir}/cliamp .

%install
%goinstall
install -m 0755 -D %{_vpath_builddir}/cliamp %{buildroot}%{_bindir}/cliamp

%files
%license LICENSE
%{_bindir}/cliamp

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Scaffold SPEC (BLOCKED: Go/CGO audio build + libdevel names TBD)
