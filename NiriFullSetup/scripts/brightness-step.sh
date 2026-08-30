#!/usr/bin/env bash
# Adaptive brightness step: 5% normally, 2% once at/below 10% so the low end
# doesn't overshoot straight to 0. noctalia's own minimum_brightness (see
# settings.toml [brightness]) is the hard floor that keeps it "dull, not off".
set -euo pipefail

dir="$1"
dev="/sys/class/backlight/$(ls /sys/class/backlight | head -n1)"
cur=$(cat "$dev/brightness")
max=$(cat "$dev/max_brightness")
pct=$(( cur * 100 / max ))

if [ "$pct" -le 10 ]; then
    step=2
else
    step=5
fi

if [ "$dir" = up ]; then
    exec noctalia msg brightness-up "eDP-1" "$step"
else
    exec noctalia msg brightness-down "eDP-1" "$step"
fi
