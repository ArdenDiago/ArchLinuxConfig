#!/usr/bin/env bash
#
# Core applications, all in the official extra repo.
#
MODULE_DESC="Core applications"

module_step() {
  pac_install vlc alacritty tmux btop less nvtop alsa-utils evtest tldr bat
}
