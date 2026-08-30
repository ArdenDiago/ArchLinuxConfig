#!/usr/bin/env bash
#
# Full system update. yay wraps pacman and updates both official-repo and
# AUR packages in one pass, so prefer it once it's available.
#
MODULE_DESC="System update"

module_step() {
  if command -v yay &>/dev/null; then
    yay -Syu --noconfirm || return 1
  else
    sudo pacman -Syu --noconfirm || return 1
  fi
  return 0
}
