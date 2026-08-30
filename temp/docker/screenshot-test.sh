#!/usr/bin/env bash
# Iteration helper used while building desktopdesigner: spins up the test
# container running the given niri config (default: test-config.kdl, which
# spawns the real shell.qml + one alacritty window), waits, screenshots,
# dumps the quickshell log, tears down. Not part of the deliverable — a
# throwaway dev loop script.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

CONFIG="${1:-test-config.kdl}"
OUT="${2:-screenshots/latest.png}"
NAME="dd-screenshot-test"

docker rm -f "$NAME" >/dev/null 2>&1 || true
WAYLAND_SOCK="${XDG_RUNTIME_DIR:-/run/user/1000}/${WAYLAND_DISPLAY:-wayland-1}"

docker run -d --name "$NAME" \
    --init --device /dev/dri \
    --tmpfs /run/user/1000:uid=1000,gid=1000,mode=0700 \
    -v "$WAYLAND_SOCK:/run/user/1000/wayland-1" \
    -v "$(cd ../.. && pwd):/workspace" \
    -e WAYLAND_DISPLAY=wayland-1 -e XDG_RUNTIME_DIR=/run/user/1000 \
    -e WALLPAPER_DIR=/workspace/temp/docker/test-wallpapers \
    desktopdesigner-test:latest \
    niri -c "/workspace/temp/docker/$CONFIG" >/dev/null

sleep 4
SOCK=$(docker exec "$NAME" sh -c 'ls /run/user/1000/niri.*.sock' | head -1)

if [ "${SPAWN_TERMINAL:-1} " = "1 " ]; then
    docker exec -e NIRI_SOCKET="$SOCK" "$NAME" niri msg action spawn -- alacritty || true
    sleep 2
fi

mkdir -p "$(dirname "$OUT")"
docker exec -e NIRI_SOCKET="$SOCK" "$NAME" sh -c "niri msg action screenshot-screen --write-to-disk=true --path /workspace/temp/docker/$OUT"
sleep 1

echo "--- quickshell log ---"
LOGDIR=$(docker exec "$NAME" sh -c 'ls -d /run/user/1000/quickshell/by-id/*/ 2>/dev/null | head -1') || true
if [ -n "${LOGDIR:-}" ]; then
    docker exec "$NAME" cat "${LOGDIR}log.log"
fi

echo "--- screenshot: temp/docker/$OUT ---"
docker rm -f "$NAME" >/dev/null 2>&1
