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
  local regen=0
  local conf=/etc/modprobe.d/nvidia.conf
  if [ -f "$conf" ] && grep -q "modeset=1" "$conf"; then
    log "Kernel modesetting (nvidia_drm modeset=1) already configured."
  else
    warn "Enabling nvidia_drm modeset=1 via $conf"
    echo "options nvidia_drm modeset=1" | sudo tee "$conf" > /dev/null
    regen=1
  fi

  # Load the NVIDIA modules from the initramfs instead of late in boot, so
  # the GPU is ready before SDDM/niri start (late async loading raced the
  # greeter into a black screen). The trailing "?" makes each module
  # optional, so an initramfs for a kernel without them still builds.
  local early=/etc/mkinitcpio.conf.d/nvidia.conf
  if [ -f "$early" ] && grep -q "nvidia_drm" "$early"; then
    log "Early NVIDIA module loading already configured."
  else
    warn "Adding NVIDIA modules to the initramfs via $early"
    echo 'MODULES+=(nvidia? nvidia_modeset? nvidia_uvm? nvidia_drm?)' | sudo tee "$early" > /dev/null
    regen=1
  fi

  # With the modules baked into the initramfs, a driver or kernel update
  # leaves a stale copy in there until it's rebuilt — this hook does that
  # automatically after every such pacman transaction.
  local hook=/etc/pacman.d/hooks/nvidia.hook
  if ! cmp -s "$SCRIPT_DIR/dotfiles/nvidia/nvidia.hook" "$hook"; then
    warn "Installing pacman hook to rebuild the initramfs on NVIDIA/kernel updates: $hook"
    sudo install -Dm644 "$SCRIPT_DIR/dotfiles/nvidia/nvidia.hook" "$hook" || return 1
  fi

  if [ "$regen" = 1 ]; then
    sudo mkinitcpio -P || warn "mkinitcpio -P failed — regenerate your initramfs manually."
    warn "A reboot is required for this to take effect."
  fi
  return 0
}
