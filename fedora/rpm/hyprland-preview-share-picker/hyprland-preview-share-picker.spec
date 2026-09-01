# Omarchy Quattro - hyprland-preview-share-picker
# Upstream: https://github.com/WhySoBad/hyprland-preview-share-picker
# Rust + GTK4 + gtk4-layer-shell. Mirrors the Arch PKGBUILD: pins the
# hyprland-protocols submodule commit, replaces build.rs (no git in the
# tarball), and builds with the nightly toolchain fetched via rustup.
%global protocols_commit 3a5c2bda1c1a4e55cc1330c782547695a93f05b2
%global rustupdir %{_builddir}/rustup

Name:           hyprland-preview-share-picker
Version:        0.2.1
Release:        1%{?dist}
Summary:        An alternative share picker for Hyprland with window and monitor previews

License:        MIT
URL:            https://github.com/WhySoBad/hyprland-preview-share-picker
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz
Source1:        https://github.com/hyprwm/hyprland-protocols/archive/%{protocols_commit}.tar.gz

BuildRequires:  rust
BuildRequires:  gtk4-devel
BuildRequires:  gtk4-layer-shell-devel
BuildRequires:  curl
Requires:       gtk4
Requires:       gtk4-layer-shell
Requires:       xdg-desktop-portal-hyprland
Requires:       hyprland
Recommends:     slurp

%description
An alternative share picker for Hyprland's screen share portal, showing live
window and monitor previews.

%prep
%autosetup -n %{name}-v%{version}
export RUSTUP_HOME=%{rustupdir}/rustup CARGO_HOME=%{rustupdir}/cargo
curl -fsSL https://sh.rustup.rs -o rustup-init.sh
sh rustup-init.sh -y --profile minimal --default-toolchain nightly >/dev/null
rmdir lib/hyprland-protocols
ln -sf %{_builddir}/hyprland-protocols-%{protocols_commit} lib/hyprland-protocols
cat > build.rs <<'EOF'
fn main() {
    println!("cargo::rustc-env=GIT_VERSION=v0.2.1-r0-release");
}
EOF

%build
export RUSTUP_HOME=%{rustupdir}/rustup CARGO_HOME=%{rustupdir}/cargo
export PATH="%{rustupdir}/cargo/bin:$PATH"
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
- Source build mirroring the Arch PKGBUILD (nightly rustup toolchain + pinned hyprland-protocols)