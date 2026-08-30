#!/usr/bin/env bash
#
# SDDM display manager. This is what Omarchy skips (it boots straight into
# Hyprland via a TTY autologin) but vanilla Arch needs a login screen where
# you actually pick a session. Hyprland and Niri (modules 15/16) each drop
# their own .desktop file into /usr/share/wayland-sessions/ when installed,
# so SDDM's session dropdown lists both automatically — no wiring needed
# here beyond having SDDM installed and enabled.
#
MODULE_DESC="Display manager (SDDM)"

module_step() {
  pac_install sddm || return 1

  if systemctl is-enabled sddm.service &>/dev/null; then
    log "sddm.service already enabled, skipping."
    return 0
  fi

  # display-manager.service is a shared alias — whichever DM was enabled
  # last owns the symlink, and a plain `enable` refuses to steal it from
  # another one already sitting there (e.g. a distro image that ships
  # with lightdm/gdm pre-enabled). --force is the Arch Wiki's documented
  # way to switch: https://wiki.archlinux.org/title/Display_manager
  local dm_alias="/etc/systemd/system/display-manager.service"
  local previous_dm=""
  if [ -L "$dm_alias" ]; then
    previous_dm="$(basename "$(readlink -f "$dm_alias")")"
  fi

  if [ -n "$previous_dm" ] && [ "$previous_dm" != "sddm.service" ]; then
    warn "Replacing existing display manager ($previous_dm) with sddm.service."
    track_rollback "sudo systemctl enable --force '$previous_dm' 2>/dev/null || true"
  else
    track_rollback "sudo systemctl disable sddm.service 2>/dev/null || true"
  fi

  sudo systemctl enable --force sddm.service || return 1
  log "Enabled sddm.service — the graphical login screen starts at next boot."
  return 0
}
