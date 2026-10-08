# Omarchy Quattro - voxtype-bin (push-to-talk dictation)
# Upstream: https://voxtype.io / https://github.com/peteonrails/voxtype (MIT).
# Omarchy integrates Voxtype for the SUPER+SPACE row Install > AI > Dictation
# (upstream bin/omarchy-voxtype-install runs `omarchy-pkg-add wtype voxtype-bin`),
# so the RPM must be named voxtype-bin. Omarchy's default config uses the Whisper
# engine (CPU or Vulkan), so this repacks only the Whisper + OSD prebuilt
# binaries, not upstream's ONNX/CUDA/MIGraphX payload.
%global debug_package %{nil}
# Prebuilt binaries carry upstream build-host RPATHs (dlopened from their own
# directory); harmless, so skip the check.
%global __brp_check_rpaths %{nil}
# Optional accelerators (Vulkan, the GTK4/Quickshell OSD) are dlopened at
# runtime; keep them out of auto-Requires so the package installs without them.
%global __requires_exclude ^(libvulkan\.so.*|libgtk-4\.so.*|libgtk4-layer-shell.*)$

Name:           voxtype-bin
Version:        1.1.0
Release:        1%{?dist}
Summary:        Push-to-talk voice-to-text for Linux (Whisper; prebuilt binaries)

License:        MIT
URL:            https://voxtype.io
Source0:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/config/default.toml#/%{name}-config-%{version}.toml
Source1:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/packaging/systemd/voxtype.service#/%{name}-service-%{version}
Source2:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/packaging/completions/voxtype.bash#/%{name}-bash-%{version}
Source3:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/packaging/completions/voxtype.zsh#/%{name}-zsh-%{version}
Source4:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/packaging/completions/voxtype.fish#/%{name}-fish-%{version}
Source5:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/LICENSE#/%{name}-LICENSE-%{version}
Source6:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/README.md#/%{name}-README-%{version}.md
Source7:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/packaging/voxtype-configure.desktop#/%{name}-configure-%{version}.desktop
Source8:        https://raw.githubusercontent.com/peteonrails/voxtype/v%{version}/packaging/scripts/voxtype-configure-launcher#/%{name}-configure-launcher-%{version}
Source9:        https://github.com/peteonrails/voxtype/archive/refs/tags/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
Source10:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-baseline#/%{name}-%{version}-baseline
Source11:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-avx2#/%{name}-%{version}-avx2
Source12:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-avx512#/%{name}-%{version}-avx512
Source13:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-vulkan#/%{name}-%{version}-vulkan
Source14:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-osd#/%{name}-%{version}-osd
Source15:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-osd-gtk4#/%{name}-%{version}-osd-gtk4
Source16:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-osd-quickshell#/%{name}-%{version}-osd-quickshell
Source17:       https://github.com/peteonrails/voxtype/releases/download/v%{version}/voxtype-%{version}-linux-x86_64-audio-bridge#/%{name}-%{version}-audio-bridge

ExclusiveArch:  x86_64
Provides:       voxtype = %{version}-%{release}

Requires:       alsa-lib
Requires:       curl
Requires:       glibc
Requires:       libgcc
Recommends:     wtype
Recommends:     wl-clipboard
Recommends:     vulkan-loader
Recommends:     gtk4-layer-shell

%description
Voxtype is push-to-talk voice-to-text for Linux, transcribed locally with
Whisper. This package repacks the upstream prebuilt x86_64 binaries (CPU
baseline/AVX2/AVX-512 plus the Vulkan GPU build and the on-screen mic
visualizer). It is the dictation backend for Omarchy's Install > AI >
Dictation menu row.

%prep
%setup -q -c -T -n %{name}-%{version}
tar -xzf "%{SOURCE9}"
cp "%{SOURCE5}" LICENSE

%build
:

%install
# Whisper CPU/GPU binaries live under %{_libdir}/voxtype; /usr/bin/voxtype is
# chosen per-CPU in %post.
install -Dm755 "%{SOURCE10}" %{buildroot}%{_libdir}/voxtype/voxtype-baseline
install -Dm755 "%{SOURCE11}" %{buildroot}%{_libdir}/voxtype/voxtype-avx2
install -Dm755 "%{SOURCE12}" %{buildroot}%{_libdir}/voxtype/voxtype-avx512
install -Dm755 "%{SOURCE13}" %{buildroot}%{_libdir}/voxtype/voxtype-vulkan
install -d %{buildroot}%{_bindir}
# Default user-facing symlink; %post retargets it to the best CPU backend.
ln -sf %{_libdir}/voxtype/voxtype-avx2 %{buildroot}%{_bindir}/voxtype

# OSD launcher + frontends. The launcher resolves /proc/self/exe and probes its
# parent directory, so it finds the frontends without PATH gymnastics.
install -Dm755 "%{SOURCE14}" %{buildroot}%{_libdir}/voxtype/voxtype-osd
install -Dm755 "%{SOURCE15}" %{buildroot}%{_libdir}/voxtype/voxtype-osd-gtk4
install -Dm755 "%{SOURCE16}" %{buildroot}%{_libdir}/voxtype/voxtype-osd-quickshell
install -d %{buildroot}%{_bindir}
ln -sf %{_libdir}/voxtype/voxtype-osd %{buildroot}%{_bindir}/voxtype-osd
install -Dm755 "%{SOURCE17}" %{buildroot}%{_bindir}/voxtype-audio-bridge

# Quickshell QML tree (frontend looks under /usr/share/voxtype/quickshell) and
# the example OSD styles/recipes, copied whole from the source archive.
install -d %{buildroot}%{_datadir}/voxtype
cp -a voxtype-%{version}/quickshell %{buildroot}%{_datadir}/voxtype/
find %{buildroot}%{_datadir}/voxtype/quickshell -type f -exec chmod 644 {} +
find %{buildroot}%{_datadir}/voxtype/quickshell -type d -exec chmod 755 {} +
install -d %{buildroot}%{_datadir}/voxtype/osd %{buildroot}%{_datadir}/voxtype/osd-recipes
cp -a voxtype-%{version}/examples/osd-packages/. %{buildroot}%{_datadir}/voxtype/osd/
cp -a voxtype-%{version}/examples/osd-recipes/. %{buildroot}%{_datadir}/voxtype/osd-recipes/
find %{buildroot}%{_datadir}/voxtype/osd -type f -exec chmod 644 {} +
find %{buildroot}%{_datadir}/voxtype/osd-recipes -type f -exec chmod 644 {} +

install -Dm755 "%{SOURCE8}" %{buildroot}%{_bindir}/voxtype-configure-launcher
install -Dm644 "%{SOURCE7}" %{buildroot}%{_datadir}/applications/voxtype-configure.desktop
install -Dm644 "%{SOURCE0}" %{buildroot}%{_sysconfdir}/voxtype/config.toml
install -Dm644 "%{SOURCE1}" %{buildroot}%{_prefix}/lib/systemd/user/voxtype.service
install -Dm644 "%{SOURCE6}" %{buildroot}%{_datadir}/doc/%{name}/README.md
install -Dm644 "%{SOURCE2}" %{buildroot}%{_datadir}/bash-completion/completions/voxtype
install -Dm644 "%{SOURCE3}" %{buildroot}%{_datadir}/zsh/site-functions/_voxtype
install -Dm644 "%{SOURCE4}" %{buildroot}%{_datadir}/fish/vendor_completions.d/voxtype.fish

%post
# Pick the best CPU backend for /usr/bin/voxtype, but preserve a GPU backend the
# user selected with `voxtype setup gpu --enable`.
if [ -f /usr/bin/voxtype ]; then
  target=$(readlink -f /usr/bin/voxtype 2>/dev/null || echo "")
  case "$target" in
    */voxtype-vulkan)
      ;;
    *)
      if grep -q avx512f /proc/cpuinfo 2>/dev/null; then
        ln -sf %{_libdir}/voxtype/voxtype-avx512 /usr/bin/voxtype
      elif grep -q avx2 /proc/cpuinfo 2>/dev/null; then
        ln -sf %{_libdir}/voxtype/voxtype-avx2 /usr/bin/voxtype
      else
        ln -sf %{_libdir}/voxtype/voxtype-baseline /usr/bin/voxtype
      fi
      ;;
  esac
fi

%files
%license LICENSE
%config(noreplace) %{_sysconfdir}/voxtype/config.toml
%{_bindir}/voxtype
%{_bindir}/voxtype-osd
%{_bindir}/voxtype-audio-bridge
%{_bindir}/voxtype-configure-launcher
%{_libdir}/voxtype/
%{_datadir}/voxtype/
%{_datadir}/applications/voxtype-configure.desktop
%{_prefix}/lib/systemd/user/voxtype.service
%{_datadir}/doc/%{name}/README.md
%{_datadir}/bash-completion/completions/voxtype
%{_datadir}/zsh/site-functions/_voxtype
%{_datadir}/fish/vendor_completions.d/voxtype.fish

%changelog
* Thu Oct 08 2026 whelanh <brickhousedevelopers@gmail.com> - 1.1.0-1
- Initial Fedora package: voxtype dictation backend for Omarchy (v1.1.0)
