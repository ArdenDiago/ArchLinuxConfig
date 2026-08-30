#!/usr/bin/env bash
#
# Niri (scrollable-tiling Wayland compositor) — the second of the two
# sessions this script offers alongside Hyprland (module 15). It's a
# proper package in Arch's official extra repo, no AUR/source build
# needed. xwayland-satellite gives it X11 app support the way Hyprland
# gets it natively from xorg-xwayland. polkit-gnome is shared with the
# Hyprland module (harmless no-op if already installed) since whichever
# session you pick at the SDDM login screen needs its own agent running.
#
# Unlike the Hyprland module (which pulls in xdg-desktop-portal-hyprland),
# niri has no portal package of its own — without one, apps like Firefox
# silently fail to screen-share and get a broken file picker. gnome/gtk
# below plus dotfiles/niri/niri-portals.conf (installed at the bottom)
# cover that; see that file for why those two specifically.
#
MODULE_DESC="Niri"

module_step() {
  # brightnessctl/playerctl/cliphist/wlogout replace the dms-ipc-routed
  # media keys, clipboard, and power menu binds below — wireplumber (wpctl)
  # and btop are already pulled in elsewhere, no dms.service dependency left.
  pac_install niri fuzzel mako swaybg xwayland-satellite \
    brightnessctl playerctl cliphist wlogout \
    polkit-gnome xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk || return 1

  mkdir -p "$HOME/.config/niri" "$HOME/.config/xdg-desktop-portal"
  install_dotfile "$SCRIPT_DIR/dotfiles/niri/config.kdl" "$HOME/.config/niri/config.kdl"
  install_dotfile "$SCRIPT_DIR/dotfiles/niri/niri-portals.conf" \
    "$HOME/.config/xdg-desktop-portal/niri-portals.conf"

  if lspci | grep -qi nvidia; then
    warn "There is a known niri+NVIDIA high-VRAM-usage quirk (heap reuse);"
    warn "  see the niri wiki's NVIDIA section if you see excessive VRAM use."
    warn "For hybrid graphics PRIME offload, launch apps with:"
    warn "  __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>"
  fi

  # config.kdl's environment{} is only read when niri itself starts, and
  # the portal daemon needs to reload to pick up niri-portals.conf — a
  # config re-source isn't enough for either. Restarting the portal here
  # covers Firefox screen-share/file-picker immediately; the env vars
  # still need a logout/login (or niri restart) to reach freshly spawned
  # apps.
  if pgrep -x niri &>/dev/null; then
    systemctl --user restart xdg-desktop-portal.service &>/dev/null || true
    warn "niri is running — log out and back in for MOZ_ENABLE_WAYLAND/GTK_USE_PORTAL to take effect in Firefox."
  fi

  return 0
}
