#!/usr/bin/env bash
#
# Multi-wallpaper switcher: drop images into ~/Pictures/Wallpapers, hit
# Super+W (Hyprland) / Mod+W (niri), and a centered carousel (carousel.qml,
# run via Quickshell) pops up over everything in that folder — h/j/k/l or
# arrow keys to browse, Enter to pick, Esc to cancel. Whatever gets picked
# is applied immediately via swaybg and remembered in
# ~/.config/wallpaper/current so it survives a logout/reboot instead of
# resetting to a solid color, and so the carousel reopens on whatever's
# currently applied instead of always starting from the first image.
#
# swaybg is already installed by modules/15-hyprland.sh and
# modules/16-niri.sh; jq (used to ask hyprctl/niri msg which output is
# focused) is already installed by modules/17-desktop-services.sh. Requires
# Quickshell + a running DankMaterialShell session (`dms run --session`) —
# neither is installed by this repo, since DMS itself is set up outside
# this automation; select.sh will simply do nothing if `quickshell` isn't
# on PATH. This module only wires select.sh (the picker), carousel.qml (the
# picker's UI), and restore.sh (session-startup restore) into place; the
# actual Super+W / Mod+W bindings and the exec-once/spawn-at-startup swap
# live in dotfiles/hypr/hyprland.conf and dotfiles/niri/config.kdl
# themselves.
#
# Deliberately does not touch the SDDM login-screen theme (modules/22) —
# that's a separate, unrelated background.
#
MODULE_DESC="Wallpaper switcher"

module_step() {
  local src="$SCRIPT_DIR/dotfiles/wallpaper"

  mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/.config/wallpaper"

  install_dotfile "$src/select.sh"    "$HOME/.config/wallpaper/select.sh"
  install_dotfile "$src/carousel.qml" "$HOME/.config/wallpaper/carousel.qml"
  install_dotfile "$src/restore.sh"   "$HOME/.config/wallpaper/restore.sh"

  chmod +x "$HOME/.config/wallpaper/"{select.sh,restore.sh}

  if [ -z "$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f 2>/dev/null)" ]; then
    log "~/Pictures/Wallpapers is empty — drop some images in, then press Super+W (Hyprland) or Mod+W (niri) to pick one."
  fi
  return 0
}
