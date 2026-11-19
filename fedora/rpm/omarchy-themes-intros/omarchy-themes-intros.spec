# Omarchy Quattro - omarchy-themes-intros (theme intro videos)
# Upstream: https://github.com/omacom/omarchy-themes-intros (MIT)
#
# The theme intro videos live in their own repository so omarchy (and each
# omarchy-dev rebuild of a quattro tip) stay small. This noarch package just
# installs the .mp4 files under /usr/share/omarchy/themes/<theme>/
# backgrounds/intros/. Pinned to a commit and versioned by date, matching
# upstream's PKGBUILD: bump both when an intro is added or changed.
%global debug_package %{nil}
%global commit 3c8d7f0d0d292898069ae264bdb89e6bdfc355c3

Name:           omarchy-themes-intros
Version:        2026.11.18
Release:        1%{?dist}
Summary:        Background intro videos for the Omarchy themes

License:        MIT
URL:            https://github.com/omacom/omarchy-themes-intros
Source0:        https://github.com/omacom/omarchy-themes-intros/archive/%{commit}.tar.gz

BuildArch:      noarch

%description
Background intro videos for the Omarchy themes. Each theme's intro plays when
the theme's background is selected; a theme without one switches straight to
the still image.

%prep
%autosetup -n %{name}-%{commit}

%install
for intro in */*.mp4; do
  theme="${intro%%/*}"
  install -Dm644 "$intro" \
    "%{buildroot}%{_datadir}/omarchy/themes/$theme/backgrounds/intros/${intro#*/}"
done

%files
%license LICENSE
%{_datadir}/omarchy/themes/

%changelog
* Thu Nov 19 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.18-1
- Initial Fedora package: theme intro videos, pinned to commit 3c8d7f0d0d
