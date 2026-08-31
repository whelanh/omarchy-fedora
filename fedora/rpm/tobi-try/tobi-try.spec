# Omarchy Quattro - tobi-try (ephemeral workspace manager, Ruby gem)
# Upstream: https://github.com/tobi/try  (Ruby gem `try-cli`)
# The manage is `try`; Omarchy pulls the `try-cli` gem. Fedora path: build a gem
# RPM from rubygems via gem2rpm, or install the gem. This spec scaffolds the
# rpmbuild of the gem.
# %OT VERIFY: the gem name is `try-cli`; confirm the installed binary (`try`)
# and Ruby version. Simplest Fedora path may be `gem2rpm --fetch try-cli`.
Name:           try
Version:        0.1.0
Release:        1%{?dist}
Summary:        Ephemeral workspace manager (try/task switcher)

License:        MIT
URL:            https://github.com/tobi/try
Source0:        https://rubygems.org/downloads/try-cli-%{version}.gem

BuildRequires:  ruby-devel
BuildRequires:  rubygems-devel
Requires:       ruby

%description
Tobi.try is a Ruby tool for ephemeral workspace management; Omarchy exposes it
as `tobi-try` for quick throwaway task workspaces.

%prep
# no-op; gem unpack handled by %gem_install style macros

%build
%gem_build

%install
%gem_install

%files
%{gem_dir}/gemfiles/*
%{gem_dir}/gems/*
%{gem_dir}/specifications/*
%{_bindir}/try

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 0.1.0-1
- Scaffold SPEC for Fedora (PENDING-VERIFY: gem name/version; may use gem2rpm)
