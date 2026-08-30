#!/usr/bin/env bash
#
# Official cross-distro installer — no Arch package exists for this. The
# installer is supposed to symlink ~/.local/bin/claude itself, but there's
# a known upstream bug where that symlink sometimes doesn't get created
# (anthropics/claude-code#67586), leaving you having to run it by its full
# versioned path under ~/.local/share/claude. ensure_on_path repairs that.
#
MODULE_DESC="Claude Code"

module_step() {
  if command -v claude &>/dev/null || [ -x "$HOME/.local/bin/claude" ]; then
    log "Claude Code already installed, skipping."
    return 0
  fi
  log "Installing Claude Code"
  curl --retry 5 --retry-delay 3 --retry-all-errors -fsSL https://claude.ai/install.sh | bash || return 1

  ensure_on_path claude \
    "$HOME/.local/bin/claude" \
    "$HOME/.local/share/claude/versions/"*"/claude"
  return 0
}
