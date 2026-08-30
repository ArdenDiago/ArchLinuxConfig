#!/bin/bash
# Toggles a floating, centered btop — bound to clicking the CPU/RAM/GPU/
# network bar meters (noctalia widget.*.actions.left, ~/.config/noctalia/
# settings.toml). niri's window-rule can't reliably float this terminal by
# app-id (app-id isn't matched in time at window-map — niri-wm/niri#3420),
# so this floats/sizes/centers it explicitly via `niri msg action` instead.

if pgrep -f 'floating-btop' >/dev/null; then
    pkill -f 'floating-btop'
    exit 0
fi

nohup alacritty --class floating-btop -e btop >/dev/null 2>&1 &
disown

sleep 0.4
niri msg action toggle-window-floating
niri msg action set-window-width 1300
niri msg action set-window-height 800
niri msg action center-window
