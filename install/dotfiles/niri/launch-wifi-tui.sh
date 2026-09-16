#!/bin/bash
# Toggles a floating, centered impala (wifi TUI, talks to iwd) — bound to
# Mod+Shift+N in place of noctalia's mouse-driven Wifi panel.
#
# niri's open-floating window-rule doesn't reliably apply to alacritty at
# window-map time (niri-wm/niri#3420), so the window-rule also sets
# opacity 0 and this script polls for the window's id (rather than a fixed
# sleep — impala's iwd/D-Bus startup time varies) and drives every action by
# --id instead of "the focused window", which is what made a fixed-sleep,
# focus-based version occasionally float/resize the wrong window or miss
# the timing. Reveals with toggle-window-rule-opacity only once floated,
# sized, and centered — otherwise it flashes tiled/fullscreen first.

APP_ID="floating-wifi-tui"

if pgrep -f "class $APP_ID" >/dev/null; then
    pkill -f "class $APP_ID"
    exit 0
fi

nohup alacritty --config-file ~/.config/alacritty/floating-tui.toml --class "$APP_ID" -e impala >/dev/null 2>&1 &
disown

win_id=""
for _ in $(seq 1 40); do
    win_id=$(niri msg -j windows | jq -r --arg app "$APP_ID" '.[] | select(.app_id == $app) | .id' | head -1)
    [ -n "$win_id" ] && break
    sleep 0.05
done
[ -z "$win_id" ] && exit 1

niri msg action toggle-window-floating --id "$win_id"
niri msg action set-window-width --id "$win_id" 900
niri msg action set-window-height --id "$win_id" 600
niri msg action center-window --id "$win_id"
niri msg action focus-window --id "$win_id"
niri msg action toggle-window-rule-opacity --id "$win_id"
