#!/usr/bin/env bash
#
# SDDM login theme: "qylock-dark" (this repo's sddm-theme/) — arden's own
# theme built on Qylock (github.com/Darkkal44/qylock): all five of its
# layouts (Sword, Forest, Field, Last of Us, Clockwork) recolored dark,
# switchable at the login screen with "/", plus a command menu, a typing
# test, and a snake game. Source of truth is local now (sddm-theme/ in
# this repo), not a GitHub fetch.
#
# Three of the five layouts (Sword, Forest, Last of Us) play an mp4
# background through QtMultimedia, which on Linux needs a GStreamer/ffmpeg
# backend to decode, and Main.qml's DropShadow effects come from
# Qt5Compat.GraphicalEffects (qt6-5compat). Dependency list is straight
# from Qylock's own SDDM-setup instructions:
# github.com/Darkkal44/qylock#sddm-setup.
#
# sddm.service can start before the GPU/DRM stack has finished settling
# on this hybrid-graphics setup (module 13 loads nvidia's modules from the
# initramfs, which narrows the window but doesn't close it). That races
# the greeter's first video decode: the greeter process crashes but Xorg
# stays up, so it looks like a black screen with just a mouse cursor. The
# drop-in below makes sddm wait for udev to finish device settling first.
#
MODULE_DESC="Login screen theme (qylock-dark)"

THEME_NAME="qylock-dark"
THEME_SRC="$SCRIPT_DIR/../sddm-theme"
THEME_SYSTEM_DIR="/usr/share/sddm/themes/$THEME_NAME"
SDDM_CONF="/etc/sddm.conf.d/theme.conf"
SDDM_DROPIN="/etc/systemd/system/sddm.service.d/wait-for-gpu.conf"

module_step() {
  pac_install qt6-declarative qt6-5compat qt6-svg qt6-multimedia qt6-multimedia-ffmpeg \
    gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg || return 1

  track_rollback "sudo rm -rf '$THEME_SYSTEM_DIR'"
  sudo mkdir -p "$(dirname "$THEME_SYSTEM_DIR")" || return 1
  sudo rm -rf "$THEME_SYSTEM_DIR"
  sudo cp -r "$THEME_SRC" "$THEME_SYSTEM_DIR" || return 1
  log "Installed theme to $THEME_SYSTEM_DIR"

  sudo mkdir -p "$(dirname "$SDDM_CONF")" || return 1
  if [ -f "$SDDM_CONF" ]; then
    if [ ! -f "$SDDM_CONF.bak" ]; then
      sudo cp "$SDDM_CONF" "$SDDM_CONF.bak"
      track_rollback "sudo mv -f '$SDDM_CONF.bak' '$SDDM_CONF' 2>/dev/null || true"
    fi
    if grep -q "^Current=" "$SDDM_CONF"; then
      sudo sed -i "s|^Current=.*|Current=$THEME_NAME|" "$SDDM_CONF"
    elif grep -q "^\[Theme\]" "$SDDM_CONF"; then
      sudo sed -i "/^\[Theme\]/a Current=$THEME_NAME" "$SDDM_CONF"
    else
      printf '\n[Theme]\nCurrent=%s\n' "$THEME_NAME" | sudo tee -a "$SDDM_CONF" > /dev/null
    fi
  else
    track_rollback "sudo rm -f '$SDDM_CONF'"
    printf '[Theme]\nCurrent=%s\n' "$THEME_NAME" | sudo tee "$SDDM_CONF" > /dev/null
  fi

  if [ ! -f "$SDDM_DROPIN" ]; then
    track_rollback "sudo rm -rf '$(dirname "$SDDM_DROPIN")'"
    sudo mkdir -p "$(dirname "$SDDM_DROPIN")" || return 1
    printf '[Unit]\nAfter=systemd-udev-settle.service\nWants=systemd-udev-settle.service\n' \
      | sudo tee "$SDDM_DROPIN" > /dev/null
    sudo systemctl daemon-reload
    log "Added sddm.service override to wait for udev/GPU settle (fixes the crash race on the video layouts)."
  fi

  log "SDDM login screen set to '$THEME_NAME' — takes effect at next login/reboot."
  return 0
}
