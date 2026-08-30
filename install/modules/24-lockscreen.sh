#!/usr/bin/env bash
#
# Lock screen: hyprlock themed to match the SDDM login screen (module 22's
# Qylock "Pixel · Night City") — same background, a split HH/MM clock,
# username, and a password field. No default circular indicator like
# swaylock's, since hyprlock's input-field is a plain pill/box already.
#
# The background is a single still frame grabbed from that theme's bg.mp4
# with ffmpeg rather than shipping another multi-MB image in this repo —
# module 22 already downloaded the video, so this just reuses it. Both
# modules 15 (Hyprland) and 16 (Niri) bind their lock key to hyprlock; it
# works on either compositor since it only needs wlr-layer-shell +
# ext-session-lock-v1, not Hyprland itself.
#
QYLOCK_VIDEO="/usr/share/sddm/themes/pixel-night-city/bg.mp4"
LOCK_BG="$HOME/.config/hypr/lockscreen.png"

MODULE_DESC="Lock screen (hyprlock)"

module_step() {
  pac_install hyprlock ffmpeg || return 1

  mkdir -p "$HOME/.config/hypr"
  install_dotfile "$SCRIPT_DIR/dotfiles/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"

  if [ -f "$LOCK_BG" ]; then
    log "Lock screen background already generated, skipping."
  elif [ -f "$QYLOCK_VIDEO" ]; then
    ffmpeg -y -ss 8 -i "$QYLOCK_VIDEO" -vframes 1 -vf "scale=1920:1080" "$LOCK_BG" &>/dev/null \
      && log "Generated lock screen background from the Qylock theme video." \
      || warn "Failed to extract a lock screen background frame — hyprlock will show a blank background until $LOCK_BG exists."
  else
    warn "Qylock theme video not found at $QYLOCK_VIDEO (module 22 may not have run) — hyprlock will show a blank background until $LOCK_BG exists."
  fi

  return 0
}
