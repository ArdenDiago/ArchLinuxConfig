#!/usr/bin/env bash
# Wrapper for the global Mod+T niri bind — see docs/06-terminal-clock.md.
# Reuses bigclock.sh's own pattern (dotfiles/tmux/tmux.conf: `bind-key t
# display-popup -w 100% -h 100% -E "~/.config/tmux/bigclock.sh"`) but
# triggered from the compositor instead of from inside an attached tmux
# client, so it needs to find a session to target itself.
set -euo pipefail

# setup.sh builds to ~/.cache (shared-folder mounts can't lock a build dir
# inside the repo); fall back to the in-repo path for a plain manual build.
BIN="$HOME/.cache/terminal-clock/target/release/terminal-clock"
[ -x "$BIN" ] || BIN="$(dirname "${BASH_SOURCE[0]}")/target/release/terminal-clock"
session="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1)"

if [ -n "$session" ]; then
    tmux display-popup -t "$session" -w 100% -h 100% -E "$BIN"
else
    alacritty -e "$BIN"
fi
