#!/usr/bin/env bash
#
# Desktop services and CLI tools the niri session leans on: NetworkManager
# and bluetooth (their D-Bus services back noctalia's widgets), jq (the
# Mod+W/Mod+Shift+W skwd-wall binds and the floating-TUI launch scripts),
# pacman-contrib's checkupdates (dotfiles/tmux/welcome.sh), the Nerd Font
# for glyph icons, and EasyEffects + the bassboost preset below. rtkit lets
# PipeWire get realtime priority — without it audio crackles whenever the
# CPU is busy.
#
# impala (wifi) and bluetuith (bluetooth) are keyboard-driven TUIs bound
# to Mod+Shift+N / Mod+B in dotfiles/niri/binds.kdl. impala talks to iwd
# directly (not NetworkManager), so iwd is installed and enabled here too
# even though NetworkManager is the system's actual connection manager.
#
MODULE_DESC="Desktop services (NetworkManager, bluetooth, media/update CLI tools)"

module_step() {
  local src="$SCRIPT_DIR/dotfiles/easyeffects"

  pac_install playerctl jq pamixer ttf-jetbrains-mono-nerd pacman-contrib \
    networkmanager bluez bluez-utils libnotify easyeffects cava iwd impala rtkit || return 1

  track_rollback "sudo systemctl disable --now NetworkManager.service 2>/dev/null || true"
  sudo systemctl enable --now NetworkManager.service || return 1

  track_rollback "sudo systemctl disable --now bluetooth.service 2>/dev/null || true"
  sudo systemctl enable --now bluetooth.service || return 1

  track_rollback "sudo systemctl disable --now iwd.service 2>/dev/null || true"
  sudo systemctl enable --now iwd.service || return 1

  aur_install bluetuith || return 1

  # EasyEffects 8.x (Qt) reads presets from XDG_DATA_HOME, not
  # ~/.config/easyeffects — confirmed by watching it auto-migrate a preset
  # dropped in the old ~/.config location into this one on startup.
  mkdir -p "$HOME/.local/share/easyeffects/output"
  install_dotfile "$src/bassboost.json" "$HOME/.local/share/easyeffects/output/bassboost.json"

  return 0
}
