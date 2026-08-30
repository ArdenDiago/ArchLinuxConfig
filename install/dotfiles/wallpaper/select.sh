#!/usr/bin/env bash
# Wallpaper picker — bound to Super+W (Hyprland) / Mod+W (niri). Opens a
# centered carousel (carousel.qml, run via Quickshell) over everything in
# ~/Pictures/Wallpapers — h/j/k/l or arrow keys to browse, Enter to pick,
# Esc to cancel — and applies whatever gets picked immediately through
# swaybg, remembering it in ~/.config/wallpaper/current so restore.sh
# brings it back on next login.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
STATE_DIR="$HOME/.config/wallpaper"
STATE_FILE="$STATE_DIR/current"
RESULT_FILE="$STATE_DIR/.picker-result"

mkdir -p "$WALLPAPER_DIR" "$STATE_DIR"

# Cleared up front so a cancelled run (carousel.qml only writes this file on
# Enter) can never be mistaken for a stale pick left over from a previous
# invocation.
rm -f "$RESULT_FILE"

# Resolve the currently focused output ourselves and hand it to carousel.qml
# via env var. Each Super+W press starts a brand new quickshell process, so
# its Hyprland IPC connection is cold — asking *it* for the focused monitor
# races the connection setup and was silently losing every time, always
# falling back to whatever Quickshell.screens[0] happens to be (the laptop
# panel), even when focus was on the HDMI output. hyprctl/niri msg here run
# in the already-live compositor connection, so there's no race.
MONITOR_NAME=""
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1; then
    MONITOR_NAME="$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null)"
elif [ -n "$NIRI_SOCKET" ] && command -v niri >/dev/null 2>&1; then
    MONITOR_NAME="$(niri msg -j focused-output | jq -r '.name' 2>/dev/null)"
fi

WALLPAPER_CAROUSEL_MONITOR="$MONITOR_NAME" quickshell -p "$SCRIPT_DIR/carousel.qml"

[ -s "$RESULT_FILE" ] || exit 0
full_path="$(cat "$RESULT_FILE")"
[ -f "$full_path" ] || exit 0

pkill -x swaybg 2>/dev/null
setsid swaybg -i "$full_path" -m fill >/dev/null 2>&1 &
disown

printf '%s' "$full_path" > "$STATE_FILE"
