#!/usr/bin/env bash
# Keep at most MAX_SESSIONS tmux sessions alive. Oldest sessions are killed
# first (FIFO queue), so the session picker (Ctrl+Shift+H in Alacritty)
# always shows only the most recent MAX_SESSIONS sessions.

MAX_SESSIONS=10

tmux list-sessions -F '#{session_id} #{session_name}' 2>/dev/null \
  | sed 's/^\$//' \
  | sort -n \
  | head -n "-${MAX_SESSIONS}" \
  | cut -d' ' -f2- \
  | while IFS= read -r name; do
      tmux kill-session -t "$name"
    done
