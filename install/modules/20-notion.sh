#!/usr/bin/env bash
#
# Notion has no official Linux build — notion-app-electron from the AUR
# wraps the web app in Electron.
#
MODULE_DESC="Notion"

module_step() {
  aur_install notion-app-electron
}
