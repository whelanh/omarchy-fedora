# Omarchy Quattro - tobi-try (ephemeral workspace manager, Ruby gem)
# Upstream: https://github.com/tobi/try  (Ruby gem `try-cli`).
# Use the standard Fedora gem packaging approach; the gem is `try-cli`.
%global debug_package %{nil}

Name:           try
Version:        1.10.1
Release:        1%{?dist}
Summary:        Ephemeral workspace manager (try/task switcher)

License:        MIT
URL:            https://github.com/tobi/try
Source0:        https://rubygems.org/downloads/%{gem_name}-%{version}.gem

BuildRequires:  ruby
BuildRequires:  rubygems-devel
Requires:       ruby(rubygems)

%global gem_name try-cli
%global gem_dir %{_datadir}/gems

%description
Tobi.try is a Ruby tool for ephemeral workspace management; Omarchy exposes it
as `tobi-try` for quick throwaway task workspaces.

%prep
%setup -q -c -T

%build
# no compilation; gem ships prebuilt code

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gem_dir} %{buildroot}%{_bindir}
gem install --local --ignore-dependencies --force --no-document \
    --install-dir %{buildroot}%{gem_dir} \
    --bindir %{buildroot}%{_bindir} %{_sourcedir}/%{gem_name}-%{version}.gem

%files
%dir %{gem_dir}
%{gem_dir}/cache/%{gem_name}-%{version}.gem
%{gem_dir}/gems/%{gem_name}-%{version}/
%{gem_dir}/specifications/%{gem_name}-%{version}.gemspec
%{_bindir}/try

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 1.10.1-1
- Verified gem version 1.10.1 from rubygems
