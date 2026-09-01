# Omarchy Quattro - tensaku (screenshot annotator, Satty fork)
# Upstream: https://github.com/jondkinney/tensaku (Rust/GTK4)
%global debug_package %{nil}
# Repack of the upstream release tarball, which carries the complete install
# tree (bin/ + share/ incl. desktop entry, icon, man page, completions, and
# licenses). No Rust/GTK toolchain needed.
Name:           tensaku
Version:        0.28.0
Release:        1%{?dist}
Summary:        Modern screenshot annotation tool for Wayland

License:        MPL-2.0
URL:            https://github.com/jondkinney/tensaku
Source0:        %{url}/releases/download/v%{version}/tensaku-v%{version}-x86_64.tar.gz

BuildArch:      x86_64

Requires:       gtk4
Requires:       gtk4-layer-shell
Requires:       libadwaita
Requires:       fontconfig

%description
Tensaku is a modern screenshot annotation tool for Wayland, forked from Satty.

%prep

%build

%install
rm -rf %{buildroot}
install -d %{buildroot}/usr
tar -xf %{SOURCE0} -C %{buildroot}/usr --strip-components=1

%files
%{_bindir}/%{name}
%{_bindir}/tensaku-edit
%{_datadir}/applications/dev.tensaku.Tensaku.desktop
%{_datadir}/icons/hicolor/scalable/apps/dev.tensaku.Tensaku.svg
%{_datadir}/licenses/%{name}/
%{_datadir}/man/man1/tensaku.1*
%{_datadir}/bash-completion/completions/tensaku
%{_datadir}/fish/vendor_completions.d/tensaku.fish
%{_datadir}/zsh/site-functions/_tensaku
%{_datadir}/nushell/completions/tensaku.nu
%{_datadir}/elvish/lib/tensaku.elv
%{_datadir}/fig/autocomplete/tensaku.ts

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.28.0-1
- Repack of upstream release tarball (v0.28.0); GPL-free MPL-2.0 tree shipped as-is