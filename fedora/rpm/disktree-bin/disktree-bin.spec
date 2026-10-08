# Omarchy Quattro - disktree-bin (treemap view of disk usage)
# Upstream: https://github.com/tobi/disktree (Rust + GPUI; ships a prebuilt
# x86_64 Linux binary). Omarchy installs it as the AUR package `disktree-bin`,
# so the RPM mirrors that name and Provides the plain `disktree` name.
%global debug_package %{nil}

Name:           disktree-bin
Version:        0.11.0
Release:        1%{?dist}
Summary:        Treemap view of disk usage

License:        MIT
URL:            https://github.com/tobi/disktree
Source0:        %{url}/releases/download/v%{version}/disktree-%{version}-x86_64-linux.tar.gz

ExclusiveArch:  x86_64
Provides:       disktree = %{version}-%{release}

Requires:       hicolor-icon-theme
Requires:       vulkan-loader

%description
Disktree visualizes disk usage as a treemap and helps identify the files and
directories that take up the most space, marking what can be removed. It is the
Omarchy disk-usage tool (shipped as `disktree-bin` on the AUR).

%prep
%autosetup -n disktree-%{version}-x86_64-linux

%build
:

%install
install -Dm755 disktree %{buildroot}%{_bindir}/disktree
install -Dm644 disktree.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/disktree.svg
install -d %{buildroot}%{_datadir}/applications
sed -e 's|@BINDIR@/||' -e 's|@VERSION@|%{version}|' disktree.desktop.in \
  > %{buildroot}%{_datadir}/applications/disktree.desktop
chmod 0644 %{buildroot}%{_datadir}/applications/disktree.desktop

%files
%license LICENSE
%doc README.md
%{_bindir}/disktree
%{_datadir}/applications/disktree.desktop
%{_datadir}/icons/hicolor/scalable/apps/disktree.svg

%changelog
* Thu Oct 08 2026 whelanh <brickhousedevelopers@gmail.com> - 0.11.0-1
- Initial Fedora package: Omarchy disk-usage treemap (v0.11.0)
