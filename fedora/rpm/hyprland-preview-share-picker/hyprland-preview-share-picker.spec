# Omarchy Quattro - hyprland-preview-share-picker
# Upstream: https://github.com/WhySoBad/hyprland-preview-share-picker
# (Rust, GTK4 + gtk4-layer-shell; vendored hyprland-protocols submodule)
# STATUS: BLOCKED (PENDING-VERIFY). Requires a NIGHTLY Rust toolchain and a
# vendored hyprland-protocols submodule (commit-pinned), plus gtk4-layer-shell
# runtime. Until gtk4-layer-shell-devel + a nightly toolchain wrapper are sorted
# in mock, this stays a scaffold.
# %OT VERIFY: confirm gtk4-layer-shell-devel availability in Fedora, pin the
# submodule, and arrange the nightly toolchain via rust-toolchain.toml or a
# fetched rustup toolchain.
Name:           hyprland-preview-share-picker
Version:        0.2.1
Release:        1%{?dist}
Summary:        Screen share picker with live preview for Hyprland

License:        MIT
URL:            https://github.com/WhySoBad/hyprland-preview-share-picker
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  gtk4-devel
BuildRequires:  gtk4-layer-shell-devel
BuildRequires:  git
Requires:       gtk4
Requires:       gtk4-layer-shell
Requires:       xdg-desktop-portal-hyprland
Requires:       hyprland
Requires:       slurp

Obsoletes:      hyprland-preview-share-picker-git

%description
A share-picker for Hyprland's screen share portal that shows a live preview.
STATUS: BLOCKED - scaffold only; nightly Rust + vendored submodule TBD.

%prep
%autosetup -n %{name}-v%{version}
# %OT VERIFY: initialize/update the vendored hyprland-protocols submodule and
# arrange the nightly toolchain (rustup + rust-toolchain.toml).

%build
# %OT VERIFY: cargo build --release (frozen) with the replacement build.rs
# that emits the schema; RUSTUP_TOOLCHAIN=nightly.

%install
# %OT VERIFY: install target/release/<binary>; also emit schema.json if the
# runtime needs it.

%files
%license LICENSE
%{_bindir}/*

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.2.1-1
- Scaffold SPEC (BLOCKED: nightly toolchain + vendored submodule TBD)
