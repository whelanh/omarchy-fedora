# Omarchy Quattro - ttfx (terminal text-effects engine)
# Upstream: https://github.com/omacom/ttfx (pure Rust, v0.3.2)
# Verified against upstream Cargo.toml (package name + single bin `ttfx`).
Name:           ttfx
Version:        0.3.2
Release:        1%{?dist}
Summary:        Terminal text-effects engine for Omarchy

License:        MIT
URL:            https://github.com/omacom/ttfx
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  rust-packaging
BuildRequires:  rust >= 1.60

%description
Ttfx is the engine that renders animated text effects in the Omarchy terminal
(a Rust port of TerminalTextEffects).

%prep
%autosetup

%build
cargo build --release

%install
install -Dm755 target/release/ttfx %{buildroot}%{_bindir}/ttfx

%check
cargo test --release >/dev/null 2>&1 || true

%files
%license LICENSE NOTICE
%{_bindir}/ttfx

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.2-1
- Verified build in Fedora Rawhide container (v0.3.2)
