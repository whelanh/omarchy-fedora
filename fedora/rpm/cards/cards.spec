# Omarchy Quattro - cards (Klondike solitaire)
# Upstream: https://github.com/omacom/cards (Qt6/CMake, MIT)
#
# Upstream added Cards to omarchy-base.packages (fad23cf81, "Install Cards by
# default"), and a migration installs it on existing machines. It is Omarchy's
# own app, so Fedora has no package for it and the COPR builds it from source;
# omacom/omarchy-pkgs is the reference for the dependency set. QtQuick.Shapes
# (qt6-qtdeclarative) draws the cards, and the window icon goes through Qt's
# SVG icon engine (qt6-qtsvg).
%global debug_package %{nil}

Name:           cards
Version:        0.1.0
Release:        1%{?dist}
Summary:        Klondike solitaire in four card series

License:        MIT
URL:            https://github.com/omacom/cards
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel

Requires:       hicolor-icon-theme
Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtsvg
Requires:       qt6-qtwayland

%description
Cards is Omarchy's own Klondike solitaire: draw three, with no limit on
passes, in four card series - one drawn in the theme's colors and three with a
look of their own. Click a card and then where it goes, drag it, or
double-click to send it to the best place. Games save after every move.

It is installed by default from Omarchy's base package list and listed in the
launcher as Cards.

%prep
%autosetup -n %{name}-%{version}

%build
# Build the app target, not upstream's test binary: the package ships the game,
# and the tests are upstream CI's job.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target %{name} -j"$(nproc)"

%install
install -Dm755 build/%{name} %{buildroot}%{_bindir}/%{name}
install -Dm644 share/cards.desktop \
    %{buildroot}%{_datadir}/applications/cards.desktop
install -Dm644 share/cards.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/cards.svg
install -Dm644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md

%files
%license LICENSE
%{_bindir}/cards
%{_datadir}/applications/cards.desktop
%{_datadir}/icons/hicolor/scalable/apps/cards.svg
%{_datadir}/doc/%{name}/README.md

%changelog
* Tue Nov 17 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Initial Fedora package (v0.1.0): Omarchy's Klondike solitaire, installed by
  default from omarchy-base.packages
