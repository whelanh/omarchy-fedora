# Omarchy Quattro - omarchy-emacs (Emacs integration with Omarchy themes/fonts)
# Upstream: https://github.com/scottjones/omarchy-emacs (noarch config + helper
# scripts; no compile). Installed on demand by the SUPER+SPACE menu row
# Install > Editor > Emacs (upstream bin/omarchy-install-editor-emacs calls
# `omarchy-pkg-aur-add omarchy-emacs` then `omarchy-install-emacs`), so it is
# NOT part of the default first-party set - only published in whelanh/omarchy.
%global debug_package %{nil}

Name:           omarchy-emacs
Version:        1.10.1
Release:        1%{?dist}
Summary:        Emacs integration with Omarchy themes and fonts

License:        MIT
URL:            https://github.com/scottjones/omarchy-emacs
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildArch:      noarch

Requires:       bash
Requires:       emacs

%description
Configuration and helpers that synchronize Emacs fonts and themes with
Omarchy. The upstream setup script installs `emacs-wayland` on Arch; Fedora
ships the Wayland-capable Emacs as `emacs`, which the build step rewrites it to.

%prep
%autosetup

%build
# Fedora ships the Wayland-capable Emacs package as `emacs`.
sed -i 's/omarchy-pkg-add emacs-wayland/omarchy-pkg-add emacs/' bin/omarchy-install-emacs

%install
install -dm755 %{buildroot}%{_datadir}/%{name}/config/themes
install -Dm644 config/init.el %{buildroot}%{_datadir}/%{name}/config/init.el
install -Dm644 config/omarchy.el %{buildroot}%{_datadir}/%{name}/config/omarchy.el
install -Dm644 config/shell-bashrc %{buildroot}%{_datadir}/%{name}/config/shell-bashrc
install -Dm644 config/themes/omarchy-theme.el %{buildroot}%{_datadir}/%{name}/config/themes/omarchy-theme.el
install -Dm644 omarchy-colors.el.tpl %{buildroot}%{_datadir}/%{name}/omarchy-colors.el.tpl
install -Dm755 hooks/font-set %{buildroot}%{_datadir}/%{name}/hooks/font-set
install -Dm755 hooks/theme-set %{buildroot}%{_datadir}/%{name}/hooks/theme-set
for command in omarchy-emacs-setup omarchy-emacs-sync-hooks omarchy-restart-emacs omarchy-install-emacs; do
  install -Dm755 bin/"$command" %{buildroot}%{_bindir}/"$command"
done

%files
%license LICENSE
%doc README.md
%{_bindir}/omarchy-emacs-setup
%{_bindir}/omarchy-emacs-sync-hooks
%{_bindir}/omarchy-restart-emacs
%{_bindir}/omarchy-install-emacs
%{_datadir}/%{name}

%changelog
* Thu Oct 08 2026 whelanh <brickhousedevelopers@gmail.com> - 1.10.1-1
- Initial Fedora package: Omarchy Emacs theme/font integration (v1.10.1)
