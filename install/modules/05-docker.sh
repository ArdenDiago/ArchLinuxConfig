#!/usr/bin/env bash
#
# Docker Engine + Compose + Buildx, all in the official extra repo — no
# third-party APT-style keyring/repo setup needed like on Debian/Ubuntu.
#
MODULE_DESC="Docker"

module_step() {
  if command -v docker &>/dev/null; then
    log "Docker already installed, skipping."
  else
    log "Installing Docker"
    pac_install docker docker-compose docker-buildx || return 1
  fi

  track_rollback "sudo systemctl disable --now docker.service 2>/dev/null || true"
  sudo systemctl enable --now docker.service || return 1

  if ! groups "$USER" | grep -qw docker; then
    track_rollback "sudo gpasswd -d '$USER' docker 2>/dev/null || true"
    sudo usermod -aG docker "$USER"
    warn "Log out/in (or run 'newgrp docker') for docker group membership to take effect."
  fi
  return 0
}
