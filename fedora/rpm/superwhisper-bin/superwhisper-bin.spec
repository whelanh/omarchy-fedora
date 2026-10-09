# Omarchy Quattro - superwhisper-bin (proprietary voice dictation)
# Upstream: https://superwhisper.com ; Omarchy recipe: omacom/omarchy-pkgs
# (pkgbuilds/superwhisper-bin). Repacks the vendor's signed portable x86_64
# Linux archive under /opt/superwhisper, mirroring Omarchy's PKGBUILD: the
# archive is verified with Minisign against the checked-in vendor release key,
# then a launcher, desktop entries, user service, fonts, icons and the fcitx5
# text-commit addon are added. Local models are downloaded by the app.
%global debug_package %{nil}
%global __strip /bin/true
%global __brp_check_rpaths %{nil}

Name:           superwhisper-bin
Version:        1.0.0
Release:        1%{?dist}
Summary:        Local and cloud voice dictation with Superwhisper

License:        LicenseRef-proprietary AND MIT
URL:            https://superwhisper.com
Source0:        https://tux.superwhisper.com/x86_64/v%{version}/superwhisper-omarchy-x86_64-%{version}.tar.zst
Source1:        https://tux.superwhisper.com/x86_64/v%{version}/superwhisper-omarchy-x86_64-%{version}.tar.zst.minisig
Source2:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/3e4cb2308ec4280500f3f083245dc8e4948f24f5/pkgbuilds/superwhisper-bin/linux-release.pub
Source3:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/3e4cb2308ec4280500f3f083245dc8e4948f24f5/pkgbuilds/superwhisper-bin/superwhisper
Source4:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/3e4cb2308ec4280500f3f083245dc8e4948f24f5/pkgbuilds/superwhisper-bin/superwhisper.service
Source5:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/3e4cb2308ec4280500f3f083245dc8e4948f24f5/pkgbuilds/superwhisper-bin/superwhisper.desktop
Source6:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/3e4cb2308ec4280500f3f083245dc8e4948f24f5/pkgbuilds/superwhisper-bin/superwhisper-url.desktop
Source7:        https://raw.githubusercontent.com/omacom/omarchy-pkgs/3e4cb2308ec4280500f3f083245dc8e4948f24f5/pkgbuilds/superwhisper-bin/setup-user

ExclusiveArch:  x86_64
AutoReqProv:    no
Provides:       superwhisper = %{version}-%{release}
Conflicts:      superwhisper

BuildRequires:  minisign
BuildRequires:  zstd
BuildRequires:  python3

Requires:       glibc
Requires:       libgcc
Requires:       libstdc++
Requires:       libgomp
Requires:       xdg-utils
Requires:       python3
Requires:       python3-gobject
Requires:       python3-cairo
Requires:       gtk4
Requires:       gtk4-layer-shell
Requires:       at-spi2-core
Requires:       pipewire-pulseaudio
Requires:       libnotify
Requires:       wl-clipboard
Requires:       ffmpeg-free
Requires:       vulkan-loader
Requires:       librsvg2
Requires:       fontconfig
Requires:       hicolor-icon-theme
Requires:       foot

Recommends:     fcitx5
Suggests:       mesa-vulkan-drivers

%description
Superwhisper is local and cloud voice dictation. This package repacks the
vendor's signed portable x86_64 Linux archive under /opt/superwhisper with a
launcher, desktop entries, user service, fonts, icons and the fcitx5
text-commit addon. Local models are downloaded through Superwhisper's settings.

%prep
minisign -Vm "%{SOURCE0}" -x "%{SOURCE1}" -p "%{SOURCE2}"
%setup -q -c -T -n %{name}-%{version}
tar --zstd -xf "%{SOURCE0}"

# Qt 6.12 adds a Color type that shadows Omarchy's palette singleton; qualify
# the bundled panel's palette references (mirrors the Omarchy PKGBUILD).
python3 - superwhisper-omarchy-x86_64-%{version}/app/assets/omarchy-plugin/superwhisper-panel <<'PY'
from pathlib import Path
import re
import sys

for path in Path(sys.argv[1]).glob("*.qml"):
    original = path.read_text()
    updated = re.sub(r"(?<![\w.])Color\b", "Commons.Color", original)
    if updated != original:
        alias = r"(?m)^import qs\.Commons(?: [0-9.]+)? as Commons[ \t]*$"
        if not re.search(alias, updated):
            updated, imports = re.subn(
                r"(?m)^(import qs\.Commons(?: [0-9.]+)?[ \t]*)$",
                r"\1\nimport qs.Commons as Commons", updated, count=1)
            if imports != 1:
                raise SystemExit("Cannot qualify palette import in %s" % path)
        if len(re.findall(alias, updated)) != 1 or re.search(r"(?<![\w.])Color\b", updated):
            raise SystemExit("Invalid palette references in %s" % path)
        path.write_text(updated)
PY

%build
:

%install
bundle=superwhisper-omarchy-x86_64-%{version}
install -dm755 %{buildroot}/opt/superwhisper
cp -a --no-preserve=ownership "$bundle/app/." %{buildroot}/opt/superwhisper/
# Omarchy owns its Dictation menu; omit the portable installer's menu writer.
rm -f %{buildroot}/opt/superwhisper/scripts/omarchy-menu-rows.py
install -Dm755 "%{SOURCE3}" %{buildroot}%{_bindir}/superwhisper
install -Dm644 "%{SOURCE4}" %{buildroot}%{_prefix}/lib/systemd/user/superwhisper.service
install -Dm644 "%{SOURCE5}" %{buildroot}%{_datadir}/applications/superwhisper.desktop
install -Dm644 "%{SOURCE6}" %{buildroot}%{_datadir}/applications/superwhisper-url.desktop
install -Dm755 "%{SOURCE7}" %{buildroot}%{_datadir}/superwhisper/setup-user
install -d %{buildroot}%{_datadir}/licenses/%{name}
cp -a "$bundle"/licenses/. %{buildroot}%{_datadir}/licenses/%{name}/
install -Dm644 "$bundle/README.md" %{buildroot}%{_datadir}/doc/%{name}/README.md
install -Dm644 "$bundle/app/assets/linux-status/SuperwhisperTUI.ttf" \
  %{buildroot}%{_datadir}/fonts/superwhisper/SuperwhisperTUI.ttf
for size in 16 32 64 128 256 512 1024; do
  install -Dm644 "$bundle/app/assets/app-icon/$size.png" \
    %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/superwhisper.png
done
install -dm755 %{buildroot}%{_datadir}/fcitx5/addon
sed 's|@LIBRARY@|/opt/superwhisper/lib/fcitx5/libsuperwhisper-fcitx5|' \
  "$bundle/app/assets/fcitx5/superwhisper.conf.in" \
  > %{buildroot}%{_datadir}/fcitx5/addon/superwhisper.conf

%files
%license %{_datadir}/licenses/%{name}
%doc %{_datadir}/doc/%{name}/README.md
%{_bindir}/superwhisper
%{_prefix}/lib/systemd/user/superwhisper.service
%{_datadir}/applications/superwhisper.desktop
%{_datadir}/applications/superwhisper-url.desktop
%{_datadir}/superwhisper/setup-user
%{_datadir}/fonts/superwhisper/
%{_datadir}/icons/hicolor/*/apps/superwhisper.png
%{_datadir}/fcitx5/addon/superwhisper.conf
/opt/superwhisper

%changelog
* Fri Oct 09 2026 whelanh <brickhousedevelopers@gmail.com> - 1.0.0-1
- Initial Fedora package: repack of the vendor Superwhisper Linux archive (v1.0.0)
