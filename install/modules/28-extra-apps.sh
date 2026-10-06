#!/usr/bin/env bash
#
# Extra applications that don't belong to any other module: Chrome and the
# Microsoft core fonts (both AUR), fuse2 (AppImages need it), cudnn (CUDA
# deep-learning library for the NVIDIA GPU), and Cisco Packet Tracer.
#
# packettracer's AUR package can't download its own source: Cisco only
# serves the .deb to logged-in NetAcad accounts, so it has to be fetched by
# hand and dropped next to the PKGBUILD first. That makes it the one
# install here that's allowed to fail without failing the module.
#
MODULE_DESC="Extra applications (Chrome, MS fonts, Packet Tracer, cudnn)"

module_step() {
  pac_install fuse2 || return 1
  if lspci | grep -qi nvidia; then
    pac_install cudnn || return 1
  fi
  aur_install google-chrome ttf-ms-fonts || return 1

  if ! aur_installed packettracer; then
    aur_install packettracer || \
      warn "packettracer needs Cisco's .deb downloaded manually from netacad.com — see the AUR page, then re-run."
  fi
  return 0
}
