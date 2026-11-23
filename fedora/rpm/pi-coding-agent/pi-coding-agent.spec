# Omarchy Quattro - pi-coding-agent (Pi, the terminal coding agent)
# Upstream: https://github.com/earendil-works/pi (MIT; Bun standalone binary)
#
# Upstream 19736 replaced Pi's mise declaration with a package: Pi is in
# omarchy-base.packages, and omarchy-default-agent opens local models in it.
# The release ships a Bun executable with its JavaScript appended, so this
# repacks upstream's tarball rather than building anything, mirroring the Arch
# PKGBUILD.
%global debug_package %{nil}
# That appended payload is why upstream marks the package !strip: rpm's
# brp-strip rewrites the file into one Bun can no longer start. Fedora's
# install-post runs brp-strip with the strip binary, so pointing the __strip
# macro at true leaves the executable untouched. Nothing here is stripped
# anyway.
%global __strip /bin/true

Name:           pi-coding-agent
Version:        1.6.0
Release:        1%{?dist}
Summary:        Pi, a terminal coding agent that works with any model provider

License:        MIT
URL:            https://github.com/earendil-works/pi
Source0:        %{url}/releases/download/v%{version}/pi-linux-x64.tar.gz
Source1:        https://raw.githubusercontent.com/earendil-works/pi/v%{version}/LICENSE#/%{name}-LICENSE

# Upstream also publishes pi-linux-arm64.tar.gz; the COPR builds x86_64 only.
BuildArch:      x86_64

%description
Pi is a terminal coding agent that works with any model provider. Omarchy ships
it as a package rather than a mise tool, and uses it as the harness that opens
local models.

%prep
%autosetup -n pi

%install
# The whole tree, beside the binary, because Pi reads its themes, docs and
# native modules from there. Ownership is not preserved: the release tarball is
# built by the CI runner.
install -d %{buildroot}%{_libdir}/%{name} %{buildroot}%{_bindir}
cp -a --no-preserve=ownership -- . %{buildroot}%{_libdir}/%{name}/
# The release tarball has no LICENSE in it, so it is a source of its own.
install -Dm644 %{SOURCE1} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

# The package updates Pi, so Pi's own check for a newer release would only
# offer a `pi update` that cannot replace it. Same wrapper as upstream's.
cat >%{buildroot}%{_bindir}/pi <<'WRAPPER'
#!/bin/sh
export PI_SKIP_VERSION_CHECK=1
exec /usr/lib64/pi-coding-agent/pi "$@"
WRAPPER
chmod 755 %{buildroot}%{_bindir}/pi

%files
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/pi
%{_libdir}/%{name}

%changelog
* Mon Nov 23 2026 whelanh <brickhousedevelopers@gmail.com> - 1.6.0-1
- Initial Fedora package (v1.6.0): repack of upstream's Bun release, installed
  by default from omarchy-base.packages (upstream 19736) in place of the mise
  tool; strip is disabled because it breaks the appended JavaScript
