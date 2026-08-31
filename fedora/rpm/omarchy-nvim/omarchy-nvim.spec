# Omarchy Quattro - omarchy-nvim (Neovim config + LazyVim cache)
# Upstream: source is omacom/omarchy-pkgs (pkgbuilds/omarchy-nvim); there is no
# standalone repo. The PKGBUILD clones LazyVim/starter, runs a headless
# `nvim +Lazy! sync`, prunes the cache, then installs to /usr/share/omarchy-nvim
# and seeds /etc/skel.
# %OT VERIFY: this is the largest and most unusual package. Confirm the exact
# source layout and the real headless-sync commands before building; the spec
# below is a faithful shape but the fetch/sync steps must be run in %prep/%build
# with network+nodejs+tree-sitter.
Name:           omarchy-nvim
Version:        2026.0.0
Release:        1%{?dist}
Summary:        Omarchy Neovim configuration and plugin cache

License:        MIT
URL:            https://github.com/omacom/omarchy-pkgs
# No single source tarball; sources are assembled in %prep from LazyVim/starter
# + the omarchy overlay. Replace Source0 once the canonical archive is known.
Source0:        https://github.com/LazyVim/starter/archive/refs/heads/main.tar.gz

BuildRequires:  git
BuildRequires:  nodejs
BuildRequires:  npm
BuildRequires:  tree-sitter-cli
Requires:       neovim >= 0.9
Requires:       git

%description
Omarchy's Neovim distribution: a curated LazyVim-based config plus a
pre-warmed plugin cache so the editor is fast on first launch.

%prep
%autosetup -n starter-main

%build
# Run a headless plugin sync against the vendored config so the cache is
# warmed into the build tree. Network access is required inside the chroot.
# %OT VERIFY: exact invocation TBD from omarchy-pkgs PKGBUILD.
nvim --headless "+Lazy! sync" +qa || :

%install
%{__mkdir_p} %{buildroot}%{_datadir}/omarchy-nvim/config
cp -a . %{buildroot}%{_datadir}/omarchy-nvim/config/
# seed /etc/skel for new users
%{__mkdir_p} %{buildroot}/etc/skel/.config
cp -a . %{buildroot}/etc/skel/.config/nvim

%files
%license LICENSE
%{_datadir}/omarchy-nvim/
/etc/skel/.config/nvim

%changelog
* Mon Aug 31 2026 whelanh <brickhousedevelopers@gmail.com> - 2026.0.0-1
- Scaffold SPEC for Fedora (PENDING-VERIFY: config source + headless sync TBD)
