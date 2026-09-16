#!/usr/bin/env bash
# Launch the isolated niri+noctalia test container, nested inside the
# host's real Wayland session (socket mount — the container can render a
# window on your desktop but can't touch host files/services outside the
# repo mount).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd ../.. && pwd)"
WAYLAND_SOCK="${XDG_RUNTIME_DIR:-/run/user/1000}/${WAYLAND_DISPLAY:-wayland-1}"

if [ ! -S "$WAYLAND_SOCK" ]; then
    echo "No Wayland socket at $WAYLAND_SOCK — are you in a graphical session?" >&2
    exit 1
fi

docker run --rm -it \
    --name niri-desktop-test \
    --init \
    --device /dev/dri \
    --tmpfs /run/user/1000:uid=1000,gid=1000,mode=0700 \
    -v "$WAYLAND_SOCK:/run/user/1000/wayland-1" \
    -v "$REPO_ROOT:/workspace:rw" \
    -e WAYLAND_DISPLAY=wayland-1 \
    -e XDG_RUNTIME_DIR=/run/user/1000 \
    -w /workspace \
    niri-desktop-test:latest

# Notes on the flags above (each one was needed — verified by trial, not guessed):
#   --init                   niri (and noctalia) don't handle SIGTERM cleanly as
#                             PID 1; without a real init forwarding/reaping signals,
#                             `docker stop`/timeout can hang instead of exiting.
#   --device /dev/dri        niri needs EGL/GBM even nested-in-a-window; without
#                             it Mesa/Zink fails and niri panics on startup.
#   --tmpfs /run/user/1000    niri and noctalia write their own IPC sockets into
#     ...uid=1000,gid=1000    $XDG_RUNTIME_DIR; Docker auto-creates that dir as
#                             root:root otherwise, which the non-root container
#                             user can't write into.
#   socket mount without :ro  connect() on a Unix socket needs write access to the
#                             socket inode itself; a read-only bind mount denies it.
