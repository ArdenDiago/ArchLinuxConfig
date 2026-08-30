#!/usr/bin/env bash
#
# NVIDIA driver verification. As of the driver 590 branch, Arch's main
# NVIDIA package is nvidia-open-dkms (open kernel modules); the old
# proprietary nvidia-dkms package was retired for Turing (RTX/GTX 16xx)
# and newer GPUs. Pascal/Maxwell or older cards are NOT supported by
# nvidia-open-dkms and need a legacy AUR package (e.g. nvidia-470xx-dkms)
# instead — this module warns rather than guessing which legacy package
# your specific card needs.
#
MODULE_DESC="NVIDIA driver"

module_step() {
  if ! lspci | grep -qi nvidia; then
    log "No NVIDIA GPU detected, skipping driver checks."
    return 0
  fi

  if pac_installed nvidia-open-dkms; then
    log "nvidia-open-dkms already installed, checking for updates."
  else
    log "Installing NVIDIA driver (nvidia-open-dkms)"
    warn "This targets Turing (RTX/GTX 16xx) and newer GPUs. If your card is"
    warn "  older (Pascal/Maxwell/Kepler), this driver will fail to load —"
    warn "  see the ArchWiki NVIDIA page for the legacy AUR package your card needs."
  fi
  pac_install nvidia-open-dkms nvidia-utils nvidia-settings || return 1

  if command -v nvidia-smi &>/dev/null; then
    log "Driver active: $(nvidia-smi --query-gpu=driver_version,name --format=csv,noheader 2>/dev/null || echo 'unknown')"
  else
    warn "nvidia-smi not found — a reboot may be needed to load the new driver."
  fi

  # niri (and Wayland compositors generally) need DRM kernel mode setting.
  # Setting it via modprobe.d is bootloader-agnostic — it works the same
  # under systemd-boot, Limine, or GRUB, unlike editing boot entries/cmdline.
  local conf=/etc/modprobe.d/nvidia.conf
  if [ -f "$conf" ] && grep -q "modeset=1" "$conf"; then
    log "Kernel modesetting (nvidia_drm modeset=1) already configured."
  else
    warn "Enabling nvidia_drm modeset=1 via $conf"
    echo "options nvidia_drm modeset=1" | sudo tee "$conf" > /dev/null
    sudo mkinitcpio -P || warn "mkinitcpio -P failed — regenerate your initramfs manually."
    warn "A reboot is required for this to take effect."
  fi
  return 0
}
