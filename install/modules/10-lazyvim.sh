#!/usr/bin/env bash
#
# LazyVim starter config on top of Neovim. Note: Arch's fd package is just
# "fd" (unlike Debian/Ubuntu's "fd-find", renamed there for a name clash).
#
MODULE_DESC="LazyVim"

module_step() {
  if [ -d "$HOME/.config/nvim" ]; then
    log "~/.config/nvim already exists, skipping LazyVim clone."
    return 0
  fi
  pac_install neovim ripgrep fd || return 1
  track_rollback "rm -rf '$HOME/.config/nvim'"
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim" || return 1
  rm -rf "$HOME/.config/nvim/.git"
  return 0
}
