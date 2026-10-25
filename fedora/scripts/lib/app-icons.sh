#!/bin/bash
# omarchy-fedora bundled application icons -> freedesktop hicolor theme
#
# Upstream's omarchy-settings package owns applications/icons/* by installing
# each bundled icon into /usr/share/icons/hicolor/{48x48,256x256,scalable}/apps,
# named the way omarchy-webapp-install's safe_icon_name() names user-added web
# apps: lowercase, runs of non-alphanumerics collapsed to a dash ("X.png" ->
# "x", "Google Contacts.png" -> "google-contacts"). The shipped launchers
# reference those names (applications/X.desktop -> Icon=x, YouTube.desktop ->
# Icon=youtube, ...), and the same name is what the dock, the app launcher and
# the floating-workspace-layout titlebars resolve through Quickshell's icon
# lookup (shell/services/AppLibrary.qml iconSource(), whose miss falls back to
# "application-x-executable" -- the generic gear).
#
# The Fedora port copies the tree and the launchers but had no equivalent of
# that packaging step, so none of the bundled names resolved: every web app
# that ships with Omarchy (X, YouTube, Discord, WhatsApp, ...) drew the gear
# instead of its own icon.
#
# Sourced by install.sh on every install/update. Safe to source repeatedly, and
# runnable on its own to repair an existing machine without a full update:
#
#   sudo ./fedora/scripts/lib/app-icons.sh
#
# Idempotent: an icon already newer than its source file is left alone, so
# `omarchy update` does not rewrite the theme on every run.

if [ -n "${OMARCHY_FEDORA_APP_ICONS_LIB:-}" ]; then return 0 2>/dev/null || exit 0; fi
OMARCHY_FEDORA_APP_ICONS_LIB=1

omarchy_fedora_install_app_icons() {
  [ "${COPY_OMARCHY:-1}" = 1 ] || return 0

  local src="${UPSTREAM:-}/applications/icons"
  [ -d "$src" ] || { warn "no bundled application icons at ${src:-<unset UPSTREAM>}; skipping"; return 0; }

  log "== Installing Omarchy application icons into the hicolor theme =="

  # Stage first: a render that fails halfway never leaves a broken icon in the
  # theme, and only files that actually change are installed.
  local stage
  stage="$(mktemp -d)"
  mkdir -p "$stage/256x256/apps" "$stage/48x48/apps" "$stage/scalable/apps"

  # ImageMagick is in upstream's base packages, so this normally resizes like
  # the PKGBUILD does. Without it, copy the PNG as-is: GTK/Qt scale a larger
  # image down from its directory just fine.
  local have_magick=0
  command -v magick >/dev/null 2>&1 && have_magick=1

  local icon file id failed=0
  local dest=/usr/share/icons/hicolor
  local -a changed=()
  local dst dst256 dst48
  for icon in "$src"/*; do
    [ -f "$icon" ] || continue
    file="$(basename "$icon")"
    id="$(printf '%s\n' "${file%.*}" \
      | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^[:alnum:]]\+/-/g; s/^-//; s/-$//')"
    [ -n "$id" ] || continue

    case "$file" in
    *.svg)
      dst="$dest/scalable/apps/$id.svg"
      [ -f "$dst" ] && [ "$dst" -nt "$icon" ] && continue
      cp "$icon" "$stage/scalable/apps/$id.svg"
      changed+=(scalable/apps/"$id.svg")
      ;;
    *)
      dst256="$dest/256x256/apps/$id.png"
      dst48="$dest/48x48/apps/$id.png"
      # mtime, not content: ImageMagick stamps date:create/date:modify into the
      # PNG, so a re-render never compares equal. Both sizes come from the same
      # source icon, so both being newer than it means nothing to do.
      [ -f "$dst256" ] && [ -f "$dst48" ] &&
        [ "$dst256" -nt "$icon" ] && [ "$dst48" -nt "$icon" ] && continue

      if (( have_magick )); then
        magick "$icon" -thumbnail 256x256 -background transparent \
          -gravity center -extent 256x256 "PNG32:$stage/256x256/apps/$id.png" 2>/dev/null &&
          magick "$icon" -thumbnail 48x48 -background transparent \
            -gravity center -extent 48x48 "PNG32:$stage/48x48/apps/$id.png" 2>/dev/null ||
          { warn "could not render $file with ImageMagick"; failed=1; continue; }
      else
        cp "$icon" "$stage/256x256/apps/$id.png"
        cp "$icon" "$stage/48x48/apps/$id.png"
      fi
      changed+=(256x256/apps/"$id.png" 48x48/apps/"$id.png")
      ;;
    esac
  done

  if (( ${#changed[@]} == 0 )); then
    log "  application icons already up to date"
    rm -rf "$stage"
    return 0
  fi

  local -a elevate=()
  (( EUID == 0 )) || elevate=(sudo)
  local rel
  for rel in "${changed[@]}"; do
    "${elevate[@]}" install -Dm 0644 "$stage/$rel" "$dest/$rel"
  done
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    "${elevate[@]}" gtk-update-icon-cache -f -t "$dest" >/dev/null 2>&1 || true
  fi

  rm -rf "$stage"

  log "  installed ${#changed[@]} icon file(s) under $dest"
  (( failed == 0 )) || warn "some bundled icons could not be rendered; check ImageMagick"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  # Standalone repair run from a git checkout: upstream/ sits at the repo root,
  # three levels above this file (fedora/scripts/lib/).
  UPSTREAM="${UPSTREAM:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/upstream}"
  COPY_OMARCHY="${COPY_OMARCHY:-1}"
  log() { printf '\033[1;34m[omarchy] %s\033[0m\n' "$*"; }
  warn() { printf '\033[1;33m[omarchy] %s\033[0m\n' "$*" >&2; }
  omarchy_fedora_install_app_icons
fi
