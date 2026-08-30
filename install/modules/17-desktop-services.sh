#!/usr/bin/env bash
#
# Desktop services and CLI tools that used to be bundled into this module
# alongside waybar, but aren't actually waybar-specific — NetworkManager
# and bluetooth (their D-Bus services back whatever bar/panel is actually
# running now, e.g. DankMaterialShell's own), plus a handful of CLI tools
# other pieces of this setup lean on:
#
# playerctl backs DMS's media widget, jq backs
# dotfiles/wallpaper/select.sh (asking hyprctl/niri msg which output is
# focused), pacman-contrib's checkupdates backs
# dotfiles/tmux/welcome.sh's update-count line, pamixer backs volume
# control, and the Nerd Font renders glyph icons throughout (DMS's bar
# included). cava + EasyEffects back the bassboost preset below.
# polkit-gnome (already spawned by modules/15-hyprland.sh and
# modules/16-niri.sh) supplies the auth agent NetworkManager needs for
# some operations.
#
# waybar itself, and its v7-theme dotfiles/click-handlers that only made
# sense wired into a waybar custom-module JSON protocol (config-*.jsonc,
# style.css, clock.sh, update.sh, window-*.sh, network-menu.sh,
# bluetooth-menu.sh, cava-spectrum.conf, media-spectrum.py,
# media-button.sh, media-boost-toggle.sh) were removed from this repo —
# no longer in use, replaced by DankMaterialShell's own bar/network/
# bluetooth/media widgets. bassboost.json is the one survivor: it's a
# plain EasyEffects preset, not waybar-specific, and still loadable
# straight from EasyEffects' own UI without any toggle script.
#
MODULE_DESC="Desktop services (NetworkManager, bluetooth, media/update CLI tools)"

module_step() {
  local src="$SCRIPT_DIR/dotfiles/easyeffects"

  pac_install playerctl jq pamixer ttf-jetbrains-mono-nerd pacman-contrib \
    networkmanager bluez bluez-utils libnotify easyeffects cava || return 1

  track_rollback "sudo systemctl disable --now NetworkManager.service 2>/dev/null || true"
  sudo systemctl enable --now NetworkManager.service || return 1

  track_rollback "sudo systemctl disable --now bluetooth.service 2>/dev/null || true"
  sudo systemctl enable --now bluetooth.service || return 1

  # EasyEffects 8.x (Qt) reads presets from XDG_DATA_HOME, not
  # ~/.config/easyeffects — confirmed by watching it auto-migrate a preset
  # dropped in the old ~/.config location into this one on startup.
  mkdir -p "$HOME/.local/share/easyeffects/output"
  install_dotfile "$src/bassboost.json" "$HOME/.local/share/easyeffects/output/bassboost.json"

  return 0
}
