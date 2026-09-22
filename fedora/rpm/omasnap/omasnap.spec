# Omarchy Quattro - omasnap (screenshot + annotation editor)
# Upstream: https://github.com/tobi/omasnap (C++/Qt6; prebuilt release only)
%global debug_package %{nil}
# Repack of the upstream Arch x86_64 release tarball (already a /usr tree),
# mirroring the AUR omasnap-bin package. Upstream publishes no source build
# (the AUR has only omasnap-bin), so the release asset is the artifact, as
# with aether/herdr. `!strip`/`!debug` in the AUR: the binary is unstripped.
Name:           omasnap
Version:        1.21.0
Release:        1%{?dist}
Summary:        Native Wayland screenshot and annotation editor for Omarchy

License:        MIT
URL:            https://github.com/tobi/omasnap
Source0:        %{url}/releases/download/v%{version}/omasnap-%{version}-archlinux-x86_64.tar.gz
Source1:        https://raw.githubusercontent.com/tobi/omasnap/v%{version}/LICENSE

BuildArch:      x86_64

Requires:       hyprland
Requires:       layer-shell-qt
Requires:       wl-clipboard
Requires:       qt6-qtbase
Recommends:     tesseract
Suggests:       tesseract-langpack-eng

%description
Omasnap is a native Wayland screenshot and annotation editor for Omarchy and
Hyprland. It supersedes Satty/Tensaku for the screenshot and imv "edit" flows.

%prep
# Filesystem-tree tarball (usr/...), not a source archive: no compile step.
%setup -q -c -T
tar xf %{SOURCE0} -C .

%build

%install
install -Dm755 usr/bin/omasnap %{buildroot}%{_bindir}/omasnap
install -Dm644 usr/share/applications/omasnap.desktop \
  %{buildroot}%{_datadir}/applications/omasnap.desktop
install -d %{buildroot}%{_datadir}/licenses/omasnap
install -m644 usr/share/licenses/omasnap/*.txt %{buildroot}%{_datadir}/licenses/omasnap/
install -Dm644 %{SOURCE1} %{buildroot}%{_datadir}/licenses/omasnap/LICENSE

%files
%{_bindir}/omasnap
%{_datadir}/applications/omasnap.desktop
%{_datadir}/licenses/omasnap/

%changelog
* Tue Sep 22 2026 whelanh <brickhousedevelopers@gmail.com> - 1.21.0-1
- Initial Fedora package: repack of upstream v1.21.0 Arch x86_64 release
