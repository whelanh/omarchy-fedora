# Omarchy Quattro - omacut (video length trimmer)
# Upstream: https://github.com/omacom/omacut  (Qt6, qmake6)
# %OT VERIFY: confirm release tag/version, binary name, and that `ffmpeg`/
# `ffprobe` are the real runtime requirements (the app shells out to them).
Name:           omacut
Version:        0.1.0
Release:        1%{?dist}
Summary:        Omarchy video length trimmer

License:        MIT
URL:            https://github.com/omacom/omacut
Source0:        %{url}/archive/refs/heads/master.tar.gz

BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
Requires:       ffmpeg

%description
Omanent - actually omacut - is a Qt6 tool to trim the length of a video file.

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
