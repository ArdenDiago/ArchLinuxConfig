#!/usr/bin/env bash
#
# Personal Alacritty + tmux setup: custom pane-splitting/session keybindings
# sent as private escape sequences from Alacritty and mapped to real tmux
# commands, mouse scroll support, vi-style copy-mode wired to the system
# clipboard via wl-copy, a session-limit hook (keeps only the last 10 tmux
# sessions), a welcome banner on every new window, and a big-clock popup.
# Files live in dotfiles/ and are copied in (not symlinked) so a later
# change to this repo doesn't silently rewrite a file you're mid-edit on.
#
# checkupdates (pacman-contrib) and sensors (lm_sensors) back two of the
# welcome banner's status lines — Debian's `apt list --upgradable` doesn't
# exist here, so the dotfiles/tmux/welcome.sh shipped in this repo already
# uses the Arch equivalent instead.
#
MODULE_DESC="Dotfiles (Alacritty + tmux)"

module_step() {
  local src="$SCRIPT_DIR/dotfiles"

  pac_install pacman-contrib lm_sensors wl-clipboard || return 1

  # sensors-detect is normally interactive; --auto answers every prompt so
  # it works unattended. It writes /etc/conf.d/lm_sensors on completion,
  # which doubles as our marker that this has already been done. Non-fatal:
  # the welcome banner already falls back to "N/A" for CPU temp if sensors
  # isn't configured.
  if [ -f /etc/conf.d/lm_sensors ]; then
    log "lm_sensors already configured, skipping sensors-detect."
  elif sudo sensors-detect --auto &>/dev/null; then
    sudo systemctl enable --now lm_sensors.service || \
      warn "Could not enable lm_sensors.service — CPU temp may not appear until next reboot."
  else
    warn "sensors-detect failed — CPU temp in the welcome banner will show N/A."
  fi

  mkdir -p "$HOME/.config/alacritty" "$HOME/.config/tmux"

  install_dotfile "$src/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  install_dotfile "$src/tmux/tmux.conf"           "$HOME/.config/tmux/tmux.conf"
  install_dotfile "$src/tmux/session_limit.sh"    "$HOME/.config/tmux/session_limit.sh"
  install_dotfile "$src/tmux/welcome.sh"          "$HOME/.config/tmux/welcome.sh"
  install_dotfile "$src/tmux/bigclock.sh"         "$HOME/.config/tmux/bigclock.sh"

  chmod +x "$HOME/.config/tmux/session_limit.sh" "$HOME/.config/tmux/welcome.sh" "$HOME/.config/tmux/bigclock.sh"

  if tmux info &>/dev/null; then
    warn "tmux is already running — run 'tmux source ~/.config/tmux/tmux.conf' or restart your session to pick up the new config."
  fi
  return 0
}
