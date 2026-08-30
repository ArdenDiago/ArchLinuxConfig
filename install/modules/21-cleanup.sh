#!/usr/bin/env bash
#
# Trim the pacman package cache and remove orphaned dependencies (packages
# that were pulled in for something else and are no longer needed by
# anything installed).
#
MODULE_DESC="Cleanup"

module_step() {
  sudo pacman -Sc --noconfirm || true

  local orphans
  orphans="$(pacman -Qtdq 2>/dev/null)" || orphans=""
  if [ -n "$orphans" ]; then
    # shellcheck disable=SC2086
    sudo pacman -Rns --noconfirm $orphans || true
  fi
  return 0
}
