# Omarchy Quattro - hyprland-preview-share-picker
# Upstream: https://github.com/WhySoBad/hyprland-preview-share-picker
# Rust + GTK4 + gtk4-layer-shell. Builds on the stable Fedora Rust toolchain;
# the git submodule (hyprland-protocols) is vendored from its pinned commit.
%global protocols_commit 3a5c2bda1c1a4e55cc1330c782547695a93f05b2

Name:           hyprland-preview-share-picker
Version:        0.2.1
Release:        1%{?dist}
Summary:        An alternative share picker for Hyprland with window and monitor previews

License:        MIT
URL:            https://github.com/WhySoBad/hyprland-preview-share-picker
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz
Source1:        https://github.com/hyprwm/hyprland-protocols/archive/%{protocols_commit}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  gtk4-devel
BuildRequires:  gtk4-layer-shell-devel
Requires:       gtk4
Requires:       gtk4-layer-shell
Requires:       xdg-desktop-portal-hyprland
Requires:       hyprland
Recommends:     slurp

%description
An alternative share picker for Hyprland's screen share portal, showing live
window and monitor previews.

%prep
%autosetup -n %{name}-%{version}
# replace the empty git-submodule placeholder with the pinned hyprland-protocols
tar -xf %{SOURCE1} --strip-components=1 -C lib/hyprland-protocols

%build
cargo build --release --locked
./target/release/hyprland-preview-share-picker schema > schema.json

%install
install -Dm755 target/release/hyprland-preview-share-picker %{buildroot}%{_bindir}/hyprland-preview-share-picker
install -Dm644 schema.json %{buildroot}%{_datadir}/hyprland-preview-share-picker/schema.json

%files
%license LICENSE
%{_bindir}/hyprland-preview-share-picker
%{_datadir}/hyprland-preview-share-picker/schema.json

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.1-1
- Source build on stable Fedora Rust; hyprland-protocols vendored at pinned commit