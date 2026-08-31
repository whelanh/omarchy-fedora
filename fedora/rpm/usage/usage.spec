# Omarchy Quattro - usage (model-usage widget + Python collectors)
# Upstream: in-tree in omacom/omarchy (Quattro branch), shell/plugins/agents
# + bin/omarchy-agent-usage-*. This is a config/script package, not a compiled
# binary.
# %OT VERIFY: this package is fetched from the monorepo, so the Source0 and the
# exact file set (QML plugin + Python collectors) must be pinned to the same
# commit as the vendored upstream/ tree. Until then this is a shape scaffold.
Name:           omarchy-usage
Version:        0.1.0
Release:        1%{?dist}
Summary:        Omarchy model-usage bar widget

License:        MIT
URL:            https://github.com/omacom/omarchy

Requires:       python3
Requires:       jq

%description
Usage reads model/agent usage counters and renders them in the Omarchy bar
widget. Ships QML plugin glue and Python collectors that write JSON state under
~/.local/state/omarchy/agents/usage/.

%prep
# Source fetched from the monorepo at a pinned commit in %{SOURCE0}.
%setup -q -n %{name}-%{version}

%install
# %OT VERIFY: real install paths TBD from upstream/ shell plugin layout.
%{__mkdir_p} %{buildroot}%{_datadir}/omarchy/usage
cp -a . %{buildroot}%{_datadir}/omarchy/usage/

%files
%license LICENSE
%{_datadir}/omarchy/usage/

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Scaffold SPEC for Fedora (PENDING-VERIFY: monorepo fetch + file set TBD)
