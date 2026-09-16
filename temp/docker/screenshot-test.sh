#!/usr/bin/env bash
# Iteration helper used while building/testing the real niri+noctalia setup:
# spins up the test container running the given niri config (default:
# test-config.kdl, which spawns noctalia + one alacritty window), waits,
# screenshots, dumps logs, tears down. Before launching niri, reproduces the
# two config-writing steps install/modules/16-niri.sh does on a real
# install: substitutes @@HOME@@ into noctalia's settings.toml and seeds the
# wallpaper it points at — both into the container's own $HOME, never the
# host's. Not part of the deliverable — a throwaway dev loop script.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

CONFIG="${1:-test-config.kdl}"
OUT="${2:-screenshots/latest.png}"
NAME="niri-desktop-screenshot-test"

docker rm -f "$NAME" >/dev/null 2>&1 || true
WAYLAND_SOCK="${XDG_RUNTIME_DIR:-/run/user/1000}/${WAYLAND_DISPLAY:-wayland-1}"

docker run -d --name "$NAME" \
    --init --device /dev/dri \
    --tmpfs /run/user/1000:uid=1000,gid=1000,mode=0700 \
    -v "$WAYLAND_SOCK:/run/user/1000/wayland-1" \
    -v "$(cd ../.. && pwd):/workspace" \
    -e WAYLAND_DISPLAY=wayland-1 -e XDG_RUNTIME_DIR=/run/user/1000 \
    niri-desktop-test:latest \
    sleep infinity >/dev/null

docker exec "$NAME" sh -c '
  mkdir -p ~/.local/state/noctalia ~/Pictures/Wallpapers
  sed "s|@@HOME@@|$HOME|g" /workspace/install/dotfiles/noctalia/settings.toml > ~/.local/state/noctalia/settings.toml
  cp /workspace/install/dotfiles/noctalia/wallpaper.jpg ~/Pictures/Wallpapers/wallpaper.jpg
'

docker exec -d "$NAME" sh -c "niri -c /workspace/temp/docker/$CONFIG > /tmp/niri.log 2>&1"

sleep 5
SOCK=$(docker exec "$NAME" sh -c 'ls /run/user/1000/niri.*.sock' | head -1)

if [ "${SPAWN_TERMINAL:-1} " = "1 " ]; then
    docker exec -e NIRI_SOCKET="$SOCK" "$NAME" niri msg action spawn -- alacritty || true
    sleep 2
fi

mkdir -p "$(dirname "$OUT")"
docker exec -e NIRI_SOCKET="$SOCK" "$NAME" sh -c "niri msg action screenshot-screen --write-to-disk=true --path /workspace/temp/docker/$OUT"
sleep 1

echo "--- niri log (stderr) ---"
docker exec "$NAME" cat /tmp/niri.log 2>&1 | tail -60

echo "--- noctalia log (if any) ---"
docker exec "$NAME" sh -c 'find ~/.local/state/noctalia ~/.cache/noctalia -iname "*.log" 2>/dev/null -exec cat {} \;' || true

echo "--- screenshot: temp/docker/$OUT ---"
docker rm -f "$NAME" >/dev/null 2>&1
