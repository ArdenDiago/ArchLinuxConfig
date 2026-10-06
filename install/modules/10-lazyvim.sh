#!/usr/bin/env bash
#
# LazyVim starter config on top of Neovim. Note: Arch's fd package is just
# "fd" (unlike Debian/Ubuntu's "fd-find", renamed there for a name clash).
#
# Plus Jupyter notebook support (jupytext.nvim + molten-nvim) — see
# docs/nvim-jupyter.md for what each piece does and why the venv is built
# from pyenv's Python rather than whatever python3 is first on PATH.
#
MODULE_DESC="LazyVim (+ Jupyter notebooks)"

NVIM_PYTHON_VERSION="3.13.7"

module_step() {
  pac_install neovim ripgrep fd python-pipx pyenv || return 1

  if [ -d "$HOME/.config/nvim" ]; then
    log "~/.config/nvim already exists, skipping LazyVim clone."
  else
    track_rollback "rm -rf '$HOME/.config/nvim'"
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim" || return 1
    rm -rf "$HOME/.config/nvim/.git"
  fi

  mkdir -p "$HOME/.config/nvim/lua/plugins" "$HOME/.config/nvim/lua/config"
  install_dotfile "$SCRIPT_DIR/dotfiles/nvim/lua/plugins/jupytext.lua" "$HOME/.config/nvim/lua/plugins/jupytext.lua"
  install_dotfile "$SCRIPT_DIR/dotfiles/nvim/lua/plugins/molten.lua" "$HOME/.config/nvim/lua/plugins/molten.lua"

  # Appended rather than shipping a whole options.lua, so LazyVim's own
  # starter file (and anything added to it by hand) is left intact.
  local options="$HOME/.config/nvim/lua/config/options.lua"
  if ! grep -q "python3_host_prog" "$options" 2>/dev/null; then
    {
      echo ""
      echo "-- dedicated venv for the python3 host provider + molten-nvim's jupyter kernel"
      echo 'vim.g.python3_host_prog = vim.fn.expand("~/.local/share/nvim/venv/bin/python")'
    } >> "$options"
  fi

  command -v jupytext &>/dev/null || pipx install jupytext || return 1

  local venv="$HOME/.local/share/nvim/venv"
  if [ -x "$venv/bin/python" ]; then
    log "nvim Python venv already exists, skipping."
  else
    # pyenv builds Python from source — a few minutes on first run. Falls
    # back to the system python3 if that build fails.
    local py="$HOME/.pyenv/versions/$NVIM_PYTHON_VERSION/bin/python3"
    if [ ! -x "$py" ] && ! pyenv install -s "$NVIM_PYTHON_VERSION"; then
      warn "pyenv could not build Python $NVIM_PYTHON_VERSION — using /usr/bin/python3 for the nvim venv instead."
      py=/usr/bin/python3
    fi
    "$py" -m venv "$venv" || return 1
    "$venv/bin/pip" install pynvim jupyter_client ipykernel nbformat || return 1
    "$venv/bin/python" -m ipykernel install --user --name python3 --display-name "Python 3 (nvim)" || return 1
  fi

  # molten writes its kernel connection file here and doesn't create it.
  mkdir -p "$HOME/.local/share/jupyter/runtime"
  return 0
}
