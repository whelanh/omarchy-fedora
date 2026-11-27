# Omarchy Quattro - omarchy-themes-intros (theme intro videos)
# Upstream: https://github.com/omacom/omarchy-themes-intros (MIT)
#
# The theme intro videos live in their own repository so omarchy (and each
# omarchy-dev rebuild of a quattro tip) stay small. This noarch package just
# installs the .mp4 files under /usr/share/omarchy/themes/<theme>/
# backgrounds/intros/. Versioned by date and built from the release tag, the
# same way the port builds omarchy-themes-loops: a version bump then always
# brings the matching content, so auto-update cannot move the version without
# moving the videos with it.
%global debug_package %{nil}

Name:           omarchy-themes-intros
Version:        2026.11.24.1
Release:        1%{?dist}
Summary:        Background intro videos for the Omarchy themes

License:        MIT
URL:            https://github.com/omacom/omarchy-themes-intros
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildArch:      noarch

%description
Background intro videos for the Omarchy themes. Each theme's intro plays when
the theme's background is selected; a theme without one switches straight to
the still image.

%prep
%autosetup -n %{name}-%{version}

%install
for intro in */*.mp4; do
  theme="${intro%%/*}"
  install -Dm644 "$intro" \
    "%{buildroot}%{_datadir}/omarchy/themes/$theme/backgrounds/intros/${intro#*/}"
done

%files
%license LICENSE
%{_datadir}/omarchy/themes/*/backgrounds/intros/

%changelog
* Fri Nov 27 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.24.1-1
- Automatic update to upstream v2026.11.24.1

* Mon Nov 23 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.22-1
- Automatic update to upstream v2026.11.22

* Sun Nov 22 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.21-1
- Automatic update to upstream v2026.11.21

* Fri Nov 20 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.19-1
- Update to 2026.11.19: adds the Starship (Starbase) intro. Build from the
  release tag instead of a pinned commit so the version and the videos can
  never drift apart.

* Thu Nov 19 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.11.18-1
- Initial Fedora package: theme intro videos, pinned to commit 3c8d7f0d0d
