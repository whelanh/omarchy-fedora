# Omarchy Quattro - ttfx (terminal text-effects engine)
# Upstream: https://github.com/omacom/ttfx  (pure Rust, clap)
# %OT VERIFY: pick a real release tag (e.g. v0.3.2) as Version and point
# Source0 at that tag's tarball; confirm `cargo build --release` produces
# `target/release/ttfx` and installs exactly the binaries/shell completions.
Name:           ttfx
Version:        0.3.2
Release:        1%{?dist}
Summary:        Terminal text-effects engine for Omarchy

License:        MIT
URL:            https://github.com/omacom/ttfx
Source0:        %{url}/archive/v%{version}.tar.gz

BuildRequires:  rust >= 1.60

%description
Ttfx is the engine that renders animated text effects in the Omarchy terminal
(used by the omarchy terminal branding).

%prep
%autosetup -n %{name}-v%{version}

%build
%cargo_build

%install
%cargo_install
# shell completions if the project emits them (clap_complete)
%{_bindir}/ttfx completion bash > %{buildroot}%{_datadir}/bash-completion/completions/ttfx 2>/dev/null || true

%files
%license LICENSE NOTICE
%{_bindir}/ttfx

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.2-1
- Scaffold SPEC for Fedora (PENDING-VERIFY: confirm release tag + completions)
