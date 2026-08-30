#!/usr/bin/env bash
set -e

Xvnc :1 -geometry 1920x1080 -depth 24 -SecurityTypes None &
sleep 1

export DISPLAY=:1
export LIBGL_ALWAYS_SOFTWARE=1
export XDG_RUNTIME_DIR=/tmp/runtime-niri
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

exec dbus-run-session -- niri -c ~/.config/niri/config.kdl
