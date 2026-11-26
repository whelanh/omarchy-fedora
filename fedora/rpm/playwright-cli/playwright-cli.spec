# Omarchy Quattro - playwright-cli (Microsoft Playwright browser automation CLI)
# Upstream: npm @playwright/cli (Apache-2.0). Microsoft publishes it only to
# npm; Omarchy packages it from the registry. Its playwright/playwright-core
# dependencies are pinned to an exact alpha, so vendor all three tarballs: the
# COPR/mock build is offline and must not run npm.
Name:           playwright-cli
Version:        0.1.25
# Keep in sync with the cli's package.json dependencies. Bump Version and this
# together; the manifest carries a matching hold: reason.
%global pwver   1.66.0-alpha-2026-11-18
Release:        1%{?dist}
Summary:        Browser automation CLI for coding agents, from Microsoft's Playwright

License:        Apache-2.0
URL:            https://github.com/microsoft/playwright-cli
Source0:        https://registry.npmjs.org/@playwright/cli/-/cli-%{version}.tgz
Source1:        https://registry.npmjs.org/playwright/-/playwright-%{pwver}.tgz
Source2:        https://registry.npmjs.org/playwright-core/-/playwright-core-%{pwver}.tgz

# Pure JavaScript; the vendored npm packages carry no ELF. Keep npm's generated
# dependency tags out of the result and depend on the interpreter explicitly.
%global __provides_exclude_from ^%{_prefix}/lib/node_modules/@playwright/cli/.*
%global __requires_exclude_from ^%{_prefix}/lib/node_modules/@playwright/cli/.*

BuildArch:      noarch

# Fedora 44 ships Node as versioned streams (nodejs22-bin owns /usr/bin/node);
# 45/rawhide provide it through the nodejs meta. A file dependency resolves to
# the right provider on every release the COPR targets.
Requires:       /usr/bin/node
Recommends:     chromium

%description
playwright-cli drives a browser for coding agents: record, generate code,
inspect selectors and take screenshots. It uses the installed Chromium/Chrome
rather than downloading a browser, and shares its session with the agent.

%prep
%setup -q -c -T -n %{name}-%{version}
mkdir -p cli playwright playwright-core
tar xzf %{SOURCE0} -C cli --strip-components=1
tar xzf %{SOURCE1} -C playwright --strip-components=1
tar xzf %{SOURCE2} -C playwright-core --strip-components=1

%build

%install
modroot=%{buildroot}%{_prefix}/lib/node_modules/@playwright/cli
install -d "$modroot/node_modules/playwright" "$modroot/node_modules/playwright-core"
cp -a cli/. "$modroot"/
cp -a playwright/. "$modroot/node_modules/playwright"/
cp -a playwright-core/. "$modroot/node_modules/playwright-core"/

# With no browser chosen by --browser, a config file or the environment,
# Playwright runs Chrome from /opt/google/chrome. Where only Chromium is
# installed, run that instead of failing on the missing Chrome (upstream's
# Omarchy PKGBUILD makes the same edit).
core="$modroot/node_modules/playwright-core/lib/coreBundle.js"
old='browser.launchOptions.channel = "chrome";'
new='if (browser.launchOptions.executablePath === void 0 \&\& !require("fs").existsSync("/opt/google/chrome/chrome") \&\& require("fs").existsSync("/usr/bin/chromium")) browser.launchOptions.executablePath = "/usr/bin/chromium"; else browser.launchOptions.channel = "chrome";'
if [ "$(grep -cF "$old" "$core")" != 1 ]; then
  echo "expected one default Chrome channel in playwright-core's coreBundle.js" >&2
  exit 1
fi
sed -i "s|$old|$new|" "$core"

# A dnf update replaces the tree, so silence npm's update notifier (which would
# only point at an `npm install -g` that cannot replace the RPM).
install -d %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/playwright-cli <<'WRAPPER'
#!/bin/sh
export NO_UPDATE_NOTIFIER=1
exec /usr/bin/node /usr/lib/node_modules/@playwright/cli/playwright-cli.js "$@"
WRAPPER
chmod 755 %{buildroot}%{_bindir}/playwright-cli

install -d %{buildroot}%{_datadir}/licenses/%{name}
install -m644 cli/LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
for f in playwright/LICENSE playwright/NOTICE; do
  install -m644 "$f" "%{buildroot}%{_datadir}/licenses/%{name}/playwright-$(basename "$f")"
done
for f in playwright-core/LICENSE playwright-core/NOTICE playwright-core/ThirdPartyNotices.txt; do
  install -m644 "$f" "%{buildroot}%{_datadir}/licenses/%{name}/playwright-core-$(basename "$f")"
done

%files
%{_bindir}/playwright-cli
%{_prefix}/lib/node_modules/@playwright/cli/
%{_datadir}/licenses/%{name}/

%changelog
* Thu Nov 26 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.25-1
- Initial Fedora package: npm @playwright/cli with vendored playwright deps
