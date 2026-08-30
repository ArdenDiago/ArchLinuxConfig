#!/usr/bin/env bash
#
# Hyprland — one of the two Wayland sessions this script offers (the other
# is Niri, module 16). Both get installed side by side; SDDM's session
# picker (module 14) is what actually chooses between them at login, not
# this script. polkit-gnome is shared with the Niri module since either
# session may be the one you log into, and each needs its own agent
# running — installing it twice via pac_install is a no-op the second time.
#
MODULE_DESC="Hyprland"

module_step() {
  pac_install hyprland xdg-desktop-portal-hyprland xorg-xwayland \
    fuzzel mako swaybg polkit-gnome || return 1

  mkdir -p "$HOME/.config/hypr"
  install_dotfile "$SCRIPT_DIR/dotfiles/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
  return 0
}
