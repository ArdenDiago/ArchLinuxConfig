#!/usr/bin/env bash
#
# The official Microsoft build isn't in the official Arch repos (trademark
# restrictions, same reason Debian excludes it) — visual-studio-code-bin
# from the AUR is the prebuilt equivalent of the .deb used on Pop!_OS.
#
MODULE_DESC="VS Code"

module_step() {
  if command -v code &>/dev/null; then
    log "VS Code already installed, skipping."
    return 0
  fi
  log "Installing VS Code"
  aur_install visual-studio-code-bin
}
