#!/usr/bin/env bash
#
# Ollama is in the official extra repo (CPU inference by default; see
# ollama-cuda/ollama-rocm/ollama-vulkan on the ArchWiki for GPU variants).
#
MODULE_DESC="Ollama"

module_step() {
  if command -v ollama &>/dev/null; then
    log "Ollama already installed, skipping."
    return 0
  fi
  log "Installing Ollama"
  pac_install ollama || return 1
  sudo systemctl enable --now ollama.service || \
    warn "Could not enable ollama.service — start it manually with 'ollama serve' when needed."
  return 0
}
