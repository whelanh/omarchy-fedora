# Omarchy Quattro - tensaku (screenshot annotator, Satty fork)
# Upstream: https://github.com/jondkinney/tensaku (crates.io tensaku)
# Rust + GTK4/libadwaita/relm4/gtk4-layer-shell; `make build-release`,
# `make install PREFIX=...`.
# STATUS: BLOCKED (PENDING-VERIFY). Needs gtk4-layer-shell + a full GTK4 Rust
# stack; verify libdevel package availability in Fedora before building.
# %OT VERIFY: confirm gtk4-layer-shell-devel and the binary name/install target.
Name:           tensaku
Version:        0.1.0
Release:        1%{?dist}
Summary:        Screenshot annotator for Hyprland (Satty fork)

License:        MPL-2.0
URL:            https://github.com/jondkinney/tensaku
Source0:        %{url}/archive/refs/heads/master.tar.gz

BuildRequires:  rust
BuildRequires:  gtk4-devel
BuildRequires:  libadwaita-devel
BuildRequires:  gtk4-layer-shell-devel
BuildRequires:  make
Requires:       gtk4
Requires:       gtk4-layer-shell
Requires:       libadwaita

%description
Tensaku annotates screenshots on Hyprland, replacing Satty in Omarchy v4.
STATUS: BLOCKED - scaffold only until the GTK4 Rust build is verified in mock.

%prep
%autosetup -n %{name}-master

%build
make build-release %{?_smp_mflags}
# or: cargo build --release

%install
%make_install PREFIX=%{_prefix}

%files
%license LICENSE
%{_bindir}/tensaku

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Scaffold SPEC (BLOCKED: GTK4-layer-shell Rust build TBD)
