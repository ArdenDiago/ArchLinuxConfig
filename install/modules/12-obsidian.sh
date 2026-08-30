#!/usr/bin/env bash
#
# Obsidian is in the official extra repo on Arch, so unlike the Pop!_OS
# script this needs no Flatpak/Flathub setup at all.
#
MODULE_DESC="Obsidian"

module_step() {
  pac_install obsidian || return 1
  mkdir -p "$HOME/Documents/ObsidianVault"
  return 0
}
