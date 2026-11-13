# Omarchy Quattro - omarchy-local-ai (local model engine + recipe catalog)
# Upstream: https://github.com/omacom/omarchy-local-ai (Python 3 stdlib engine +
# a TOML recipe catalog, MIT). Omarchy's bin/omarchy-agent-local puts it on
# `omarchy agent local <cmd>`; the agents panel reads its status.json/list.json
# to offer local models that fit the machine. It is a base package (every
# machine gets it so the panel can evaluate recipes), and models themselves only
# run once `omarchy agent local use` installs podman (see %description).
#
# The engine loads the catalog from the directory it is installed in, so the
# tree below ships as one unit -- do not split recipes/ into another package.
%global debug_package %{nil}

Name:           omarchy-local-ai
Version:        0.6.4
Release:        1%{?dist}
Summary:        Run open models locally for Omarchy's coding agents

License:        MIT
URL:            https://github.com/omacom/omarchy-local-ai
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildArch:      noarch

# tomllib needs 3.11+; every supported Fedora ships newer.
BuildRequires:  python3

Requires:       python3
# Drive the model servers as user Quadlet units.
Requires:       systemd

# Containers run the models: upstream's `omarchy agent local use` installs
# podman + crun (and nvidia-container-toolkit on an NVIDIA machine) on demand.
Suggests:       podman
Suggests:       crun

%description
The local-model engine and its curated recipe catalog for Omarchy. It resolves
recipes for the machine's hardware, downloads pinned model weights, and manages
rootless Podman model servers as user units. Installing the package only makes
the catalog available to the Omarchy agents panel; container runtime and
weights are fetched the first time a model is set up.

%prep
%autosetup

%build
# No compile step: the engine is Python and the catalog is data.

%check
# Offline catalog validation (schema, recipe/runtime cross-references). This is
# the same check upstream's PKGBUILD runs.
./omarchy-local-ai validate .

%install
install -dm755 %{buildroot}%{_datadir}/%{name}
cp -a catalog.toml best.toml recipes runtimes reviews measurements \
  %{buildroot}%{_datadir}/%{name}/
install -Dm644 agent_local.py %{buildroot}%{_datadir}/%{name}/agent_local.py
install -Dm755 omarchy-local-ai %{buildroot}%{_datadir}/%{name}/omarchy-local-ai
install -dm755 %{buildroot}%{_bindir}
# Relative so the payload has no absolute symlink (rpm/Fedora style); the engine
# resolves its own path, so it still finds the catalog beside itself.
ln -s ../share/%{name}/omarchy-local-ai %{buildroot}%{_bindir}/omarchy-local-ai

%files
%license LICENSE
%doc README.md
# The engine contract doc upstream ships for the installed tree.
%doc docs/engine.md
%{_bindir}/omarchy-local-ai
%{_datadir}/%{name}

%changelog
* Thu Nov 12 2026 whelanh <brickhousedevelopers@gmail.com> - 0.6.4-1
- Automatic update to upstream v0.6.4

* Mon Nov 9 2026 whelanh <brickhousedevelopers@gmail.com> - 0.5.0-1
- Automatic update to upstream v0.5.0

* Tue Nov 3 2026 whelanh <brickhousedevelopers@gmail.com> - 0.4.0-1
- Automatic update to upstream v0.4.0

* Mon Nov 02 2026 whelanh <brickhousedevelopers@gmail.com> - 0.3.2-1
- Initial Fedora package: local model engine + recipe catalog (v0.3.2)
