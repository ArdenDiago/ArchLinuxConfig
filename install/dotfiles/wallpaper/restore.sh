#!/usr/bin/env bash
# Run at session startup (exec-once / spawn-at-startup) instead of a
# hardcoded swaybg call — reapplies whatever select.sh last saved, or
# falls back to a solid background if nothing's been picked yet.

STATE_FILE="$HOME/.config/wallpaper/current"

pkill -x swaybg 2>/dev/null

if [ -s "$STATE_FILE" ]; then
    wallpaper="$(cat "$STATE_FILE")"
    if [ -f "$wallpaper" ]; then
        exec swaybg -i "$wallpaper" -m fill
    fi
fi

exec swaybg -c 1e1e2e
