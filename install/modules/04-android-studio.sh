#!/usr/bin/env bash
#
# Android Studio is AUR-only on Arch (aur.archlinux.org/packages/android-studio).
#
MODULE_DESC="Android Studio"

module_step() {
  if aur_installed android-studio; then
    log "android-studio already installed, skipping."
    return 0
  fi
  aur_install android-studio
}
