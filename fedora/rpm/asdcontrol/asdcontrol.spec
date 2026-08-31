# Omarchy Quattro - asdcontrol (Apple Studio Display brightness control)
# Upstream: https://github.com/nikosdion/asdcontrol  (C++, make)
# STATUS: BLOCKED. Upstream was archived Aug 2025 and is unmaintained. It only
# targets Apple Studio Display / XDR panels, so it has almost no relevance to a
# generic Fedora desktop. Likely will be DROPPED from the Fedora mapping rather
# than packaged. Scaffold kept for completeness.
# %OT VERIFY: decide drop-vs-package; if kept, confirm the `make install`
# target (installs /usr/local/bin/asdcontrol + a udev rule) and GPL-2.0 files.
Name:           asdcontrol
Version:        1.0.0
Release:        1%{?dist}
Summary:        Apple Studio Display brightness control (archived upstream)

License:        GPL-2.0
URL:            https://github.com/nikosdion/asdcontrol
Source0:        %{url}/archive/refs/heads/main.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  libusb1-devel
BuildRequires:  hidapi-devel

%description
Controls the brightness/volume of Apple Studio Display and XDR displays over
USB. STATUS: BLOCKED (upstream archived, hardware-specific; likely dropped on
Fedora).

%prep
%autosetup -n %{name}-main

%build
make %{?_smp_mflags}

%install
# %OT VERIFY: upstream `make install` writes /usr/local/bin; force /usr.
make install DESTDIR=%{buildroot} PREFIX=%{_prefix}
install -d %{buildroot}%{_udevrulesdir}
install -m 0644 51-*-asdcontrol.rules %{buildroot}%{_udevrulesdir}/ 2>/dev/null || true

%files
%license LICENSE
%{_bindir}/asdcontrol
%{_udevrulesdir}/*.rules

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 1.0.0-1
- Scaffold SPEC (BLOCKED: archived upstream; recommend drop on Fedora)
