#!/usr/bin/env bash
#
# ble.sh gives bash fish/zsh-style autosuggestions (ghost-text completions
# from history) and syntax highlighting, without switching shells. Installed
# from the AUR since it's not in the official repos.
#
MODULE_DESC="ble.sh (bash autosuggestions)"

BLESH_SOURCE_LINE='source /usr/share/blesh/ble.sh'

module_step() {
  if aur_installed blesh; then
    log "blesh already installed, skipping."
  else
    aur_install blesh || return 1
  fi

  install_dotfile "$SCRIPT_DIR/dotfiles/blesh/blerc" "$HOME/.blerc"

  # ble.sh must be sourced as the very last line of .bashrc — it hooks the
  # line editor after everything else (prompt, aliases, other rc changes)
  # has already loaded.
  if grep -qF "$BLESH_SOURCE_LINE" "$HOME/.bashrc" 2>/dev/null; then
    log "ble.sh already wired into ~/.bashrc, skipping."
    return 0
  fi

  {
    echo ''
    echo '# ble.sh: bash autosuggestions + syntax highlighting — keep this last.'
    echo "$BLESH_SOURCE_LINE"
  } >> "$HOME/.bashrc"
  log "Added ble.sh to ~/.bashrc. Open a new terminal to see autosuggestions."
}
