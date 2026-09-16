#!/usr/bin/env bash
#
# Memory pressure handling — zram swap sizing + systemd-oomd.
#
# Found live on this machine: zram was sized at `ram / 2` (the
# zram-generator default) and filled to 100% under normal desktop load
# (a handful of Chrome/Firefox windows + several Claude Code sessions),
# at which point the kernel had nowhere left to page anonymous memory to
# and started thrashing instead — evicting and immediately re-reading
# file-backed pages. `/proc/pressure/memory` showed ~48% "full" (every
# runnable task stalled on memory at once) and the kernel OOM killer had
# already fired once, killing a bash process in a tmux scope. Load
# average hit 56 on a 12-core machine even though actual CPU compute was
# low — almost all of it was processes queued in D-state waiting on the
# kernel, not real work.
#
# Two independent fixes, both needed:
#   1. Bigger zram (`ram` instead of `ram / 2`) buys more headroom before
#      swap fills up at all.
#   2. systemd-oomd, opted into per-session pressure-based killing, so
#      that if memory pressure spikes again anyway, it kills the worst
#      offender in the user session before the whole system thrashes —
#      ships with systemd but is disabled by default, and even once
#      enabled only watches the system-wide swap limit unless a slice
#      explicitly opts in to ManagedOOMMemoryPressure=kill.
#
MODULE_DESC="Memory tuning (zram size + systemd-oomd)"

module_step() {
  pac_install zram-generator || return 1

  local zram_conf=/etc/systemd/zram-generator.conf
  if [ -f "$zram_conf" ] && grep -q "^zram-size = ram$" "$zram_conf"; then
    log "zram already sized at full RAM, skipping."
  else
    warn "Sizing zram swap to full RAM (was: ram / 2 default) via $zram_conf"
    if [ -f "$zram_conf" ] && [ ! -f "$zram_conf.bak" ]; then
      sudo cp "$zram_conf" "$zram_conf.bak"
    fi
    track_rollback "sudo mv '$zram_conf.bak' '$zram_conf' 2>/dev/null || sudo rm -f '$zram_conf'"
    printf '[zram0]\nzram-size = ram\ncompression-algorithm = zstd\n' | sudo tee "$zram_conf" > /dev/null
    sudo systemctl restart systemd-zram-setup@zram0.service || return 1
  fi

  track_rollback "sudo systemctl disable --now systemd-oomd 2>/dev/null || true"
  sudo systemctl enable --now systemd-oomd || return 1

  local oomd_dir=/etc/systemd/system/user.slice.d
  local oomd_conf="$oomd_dir/oomd.conf"
  if [ -f "$oomd_conf" ] && grep -q "ManagedOOMMemoryPressure=kill" "$oomd_conf"; then
    log "systemd-oomd already opted into user.slice pressure kills, skipping."
  else
    warn "Opting user.slice into pressure-based kills (50% threshold) via $oomd_conf"
    sudo mkdir -p "$oomd_dir"
    track_rollback "sudo rm -f '$oomd_conf'"
    printf '[Slice]\nManagedOOMMemoryPressure=kill\nManagedOOMMemoryPressureLimit=50%%\n' | sudo tee "$oomd_conf" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl restart systemd-oomd || return 1
  fi

  return 0
}
