#!/usr/bin/env bash
#
# skwd-wall: the wallpaper picker actually in use now (a quickshell app),
# replacing the DankMaterialShell-era swaybg carousel modules/23-wallpaper.sh
# still installs — that module is dead code at this point (see
# dotfiles/niri/binds.kdl: Mod+W/Mod+Shift+W both point at skwd-wall, not
# select.sh) but hasn't been removed yet. skwd-wall and skwd-daemon-bin are
# AUR-only; quickshell and matugen (both dependencies) are now in Arch's
# official extra repo, so those two come from pac_install instead.
#
# The two QML files below (SliceDelegate.qml, WallpaperSelector.qml) are
# hand-patched copies of files skwd-wall installs to
# /usr/share/skwd-wall/qml/wallpaper/ — restyled to a fixed dark/white/
# monospace "terminal card" look (straight rounded-rect cards, white
# borders, mono type) instead of skwd-wall's default skewed,
# theme-accent-colored slices, plus a fade-in fix for a one-frame
# unmasked/unbordered flash on first open. Since they live under
# /usr/share (root-owned, not a user dotfile), reapplying them needs sudo
# and happens after the package install below — and, being a patch to a
# package file rather than a config, a later `pacman -Syu`/`yay -Syu` of
# skwd-wall WILL silently revert them; there's no fixing that from here,
# just rerun this module (or install/setup.sh) afterward to reapply.
#
MODULE_DESC="Wallpaper picker (skwd-wall)"

module_step() {
  local src="$SCRIPT_DIR/dotfiles/skwd-wall"
  local qml_dir="/usr/share/skwd-wall/qml/wallpaper"

  pac_install quickshell matugen || return 1
  aur_install skwd-daemon-bin skwd-wall || return 1

  mkdir -p "$HOME/.config/skwd-wall" "$HOME/Pictures/Wallpapers"
  install_dotfile "$src/config.json" "$HOME/.config/skwd-wall/config.json"

  track_rollback "systemctl --user disable --now skwd-daemon.service 2>/dev/null || true"
  systemctl --user enable --now skwd-daemon.service || return 1

  # sudo-aware equivalent of install_dotfile for the two patched package
  # files (world-readable, so the cmp below needs no sudo, only the cp
  # does): back up skwd-wall's original the first time only, so a later
  # rerun never overwrites that backup with an already-patched copy.
  local f dest
  for f in SliceDelegate.qml WallpaperSelector.qml; do
    dest="$qml_dir/$f"
    if [ -f "$dest" ] && cmp -s "$src/$f" "$dest"; then
      log "$f already patched, skipping."
      continue
    fi
    if [ -f "$dest" ] && [ ! -f "$dest.orig-bak" ]; then
      sudo cp "$dest" "$dest.orig-bak"
      warn "Backed up skwd-wall's original $f to $f.orig-bak"
    fi
    sudo cp "$src/$f" "$dest" || return 1
    log "Patched $f."
  done

  if [ -z "$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f 2>/dev/null)" ]; then
    log "~/Pictures/Wallpapers is empty — drop some images in, then press Mod+W to pick one."
  fi

  return 0
}
