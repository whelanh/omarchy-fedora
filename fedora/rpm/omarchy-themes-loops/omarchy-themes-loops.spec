# Omarchy Quattro - omarchy-themes-loops (theme background loops)
# Upstream: https://github.com/omacom/omarchy-themes-loops (MIT)
#
# The theme background loops live in their own repository so omarchy (and each
# omarchy-dev rebuild of a quattro tip) stay small. This noarch package just
# installs the .mp4 files under /usr/share/omarchy/themes/<theme>/
# backgrounds/loops/, which omarchy-theme-set copies into the staged theme.
# Versioned by date and built from the release tag, matching upstream's
# PKGBUILD.
%global debug_package %{nil}

Name:           omarchy-themes-loops
Version:        2026.11.22
Release:        1%{?dist}
Summary:        Live background loops for the Omarchy themes

License:        MIT
URL:            https://github.com/omacom/omarchy-themes-loops
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildArch:      noarch

%description
Live background loops for the Omarchy themes. A theme's loop plays in place of
its still background when the background is set to loop; a theme without one
keeps the still image.

%prep
%autosetup -n %{name}-%{version}

%install
for loop in */*.mp4; do
  theme="${loop%%/*}"
  install -Dm644 "$loop" \
    "%{buildroot}%{_datadir}/omarchy/themes/$theme/backgrounds/loops/${loop#*/}"
done

%files
%license LICENSE
%{_datadir}/omarchy/themes/*/backgrounds/loops/

%changelog
* Mon Nov 23 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.22-1
- Automatic update to upstream v2026.11.22

* Fri Nov 20 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.19-1
- Initial Fedora package: theme background loops, built from the v2026.11.19
  release tag
