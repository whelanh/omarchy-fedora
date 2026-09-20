# Omarchy Quattro - elsewhen (world clock plugin for the Omarchy shell)
# Upstream: https://github.com/omacom/elsewhen (QML/JS/Python, noarch)
# Repack of the upstream tag archive, mirroring the Arch PKGBUILD's explicit
# runtime allow-list. There is no build step: the package *is* the plugin tree
# the shell loads, made available via a ~/.config/omarchy/plugins symlink.
Name:           elsewhen
Version:        1.0.0
Release:        1%{?dist}
Summary:        World clock plugin for the Omarchy shell

License:        MIT
URL:            https://github.com/omacom/elsewhen
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildArch:      noarch

Requires:       quickshell
Requires:       python3

%description
Elsewhen is the world clock plugin for the Omarchy shell, with a spinnable
globe. It ships as a plugin tree under /usr/share/omarchy/plugins/ and is made
available to the shell by a symlink in ~/.config/omarchy/plugins/. The plugin
shells out to python3 for its facts feed.

%prep
%autosetup -n %{name}-%{version}

%install
# Explicit allow-list (same as upstream's PKGBUILD): tests/, .github/ and the
# rest of the source tree never reach the package. An unmatched glob is left
# literal and fails the install, which is the right outcome for a release tree
# that is missing its QML or JS.
plugin=%{buildroot}%{_datadir}/omarchy/plugins/omacom.elsewhen
install -d "$plugin"
for f in manifest.json cities.json world.json worldclock-data.py *.qml *.js; do
  install -m644 "$f" "$plugin/$f"
done

%check
# The shell loads the entry point the manifest declares. A tree missing either
# would install cleanly and never load, so fail here instead.
test -f manifest.json
grep -Eq '"id"[[:space:]]*:[[:space:]]*"omacom\.elsewhen"' manifest.json
grep -Eq '"barWidget"[[:space:]]*:[[:space:]]*"Panel\.qml"' manifest.json
test -f Panel.qml

%files
%license LICENSE
%doc README.md
%{_datadir}/omarchy/plugins/omacom.elsewhen/

%changelog
* Sun Sep 20 2026 whelanh <brickhousedevelopers@gmail.com> - 1.0.0-1
- Initial Fedora package: world clock plugin from upstream v1.0.0
