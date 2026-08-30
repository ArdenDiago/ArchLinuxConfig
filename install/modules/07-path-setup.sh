#!/usr/bin/env bash
#
# Several later modules (Claude Code, Antigravity) install into
# ~/.local/bin. Add it to PATH in whichever shell rc files exist, since
# Arch Linux users commonly run bash, zsh, or both. Also exports it into
# *this* running script's PATH immediately, so commands installed later in
# this same run (claude, antigravity) resolve without opening a new shell.
#
MODULE_DESC="PATH setup"

module_step() {
  local line='export PATH="$HOME/.local/bin:$PATH"'
  local any_rc=0
  local updated=0
  local rc

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    any_rc=1
    if grep -qF '$HOME/.local/bin' "$rc" 2>/dev/null; then
      log "~/.local/bin already on PATH in $(basename "$rc")."
    else
      echo "$line" >> "$rc"
      log "Added ~/.local/bin to PATH in $(basename "$rc")."
      updated=1
    fi
  done

  if [ "$any_rc" -eq 0 ]; then
    echo "$line" >> "$HOME/.bashrc"
    log "Created ~/.bashrc with ~/.local/bin on PATH."
    updated=1
  fi

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac

  if [ "$updated" -eq 1 ]; then
    log "Open a new terminal (or source your shell rc file) for future sessions to pick it up."
  fi
  return 0
}
