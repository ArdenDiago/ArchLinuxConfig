#!/usr/bin/env bash
#
# Notion has no official Linux build in the Arch repos — notion-app from the
# AUR wraps the web app in Electron, same approach as VS Code's AUR package.
#
MODULE_DESC="Notion"

module_step() {
  if aur_installed notion-app; then
    log "notion-app already installed, skipping."
    return 0
  fi
  aur_install notion-app
  aur_install notion-app-electron

}
