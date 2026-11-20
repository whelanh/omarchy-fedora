# Omarchy Quattro - fantasi (image generation with local models)
# Upstream: https://github.com/omacom/fantasi (Qt6/CMake, MIT)
#
# Upstream added Fantasi to omarchy-base.packages; it is Omarchy's own app, so
# Fedora has no package for it and the COPR builds it from source.
# omacom/omarchy-pkgs is the reference for the dependency set.
%global debug_package %{nil}

Name:           fantasi
Version:        0.1.5
Release:        1%{?dist}
Summary:        Make and change images with Omarchy local image models

License:        MIT
URL:            https://github.com/omacom/fantasi
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtshadertools-devel

Requires:       /usr/bin/ffmpeg
Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       qt6-qtsvg
Requires:       qt6-qtwayland
Requires:       xdg-desktop-portal

%description
Fantasi makes and changes images with Omarchy's local image models.

It is installed by default from Omarchy's base package list and listed in the
launcher as Fantasi.

%prep
%autosetup -n %{name}-%{version}

%build
# Build the app target, not upstream's test binary: the tests are upstream CI's
# job.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target %{name} -j"$(nproc)"

%install
install -Dm755 build/%{name} %{buildroot}%{_bindir}/%{name}
install -Dm644 share/%{name}.desktop \
    %{buildroot}%{_datadir}/applications/%{name}.desktop
install -Dm644 share/%{name}.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/%{name}.svg

%files
%license LICENSE
%{_bindir}/fantasi
%{_datadir}/applications/fantasi.desktop
%{_datadir}/icons/hicolor/scalable/apps/fantasi.svg

%changelog
* Fri Nov 20 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.5-1
- Automatic update to upstream v0.1.5

* Thu Nov 19 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.2-1
- Initial Fedora package (v0.1.2): Omarchy's local image model app, installed
  by default from omarchy-base.packages
