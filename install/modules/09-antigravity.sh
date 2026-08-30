#!/usr/bin/env bash
#
# Two separate Google-shipped tools under the "Antigravity" name, neither
# packaged for Arch:
#   - the Antigravity IDE (GUI) — only ships as a tarball from Google's CDN
#   - the Antigravity CLI (the `agy` binary) — installed by Google's own
#     script, which supports a --dir flag to redirect where it lands
# Both are kept under ~/.config/antigravity (by request, to keep program
# files out of ~/.local) with just a thin symlink in ~/.local/bin so the
# commands still resolve globally. Each half is tried independently so one
# failing doesn't block the other; the module only reports failure (and
# rolls back) if either one didn't make it.
#
MODULE_DESC="Antigravity (IDE + CLI)"

module_step() {
  local failed=0
  local ide_dir="$HOME/.config/antigravity/ide"
  local cli_dir="$HOME/.config/antigravity/cli"

  if [ -x "$ide_dir/antigravity-ide" ]; then
    log "Antigravity IDE already installed, skipping."
  else
    log "Installing Antigravity IDE"
    local url="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.1.1-6123990880747520/linux-x64/Antigravity%20IDE.tar.gz"
    local tarball="$TMPDIR/antigravity.tar.gz"
    if curl --retry 5 --retry-delay 3 --retry-all-errors -C - -fSL "$url" -o "$tarball"; then
      mkdir -p "$ide_dir"
      track_rollback "rm -rf '$ide_dir' '$HOME/.local/bin/antigravity'"
      if tar -xzf "$tarball" -C "$ide_dir" --strip-components=1; then
        ensure_on_path antigravity "$ide_dir/antigravity-ide"
      else
        warn "Antigravity IDE archive extraction failed."
        failed=1
      fi
    else
      warn "Antigravity IDE download failed."
      failed=1
    fi
  fi

  if command -v agy &>/dev/null || [ -x "$cli_dir/agy" ]; then
    log "Antigravity CLI (agy) already installed, skipping."
  else
    log "Installing Antigravity CLI"
    track_rollback "rm -rf '$cli_dir' '$HOME/.local/bin/agy'"
    if curl --retry 5 --retry-delay 3 --retry-all-errors -fsSL https://antigravity.google/cli/install.sh | bash -s -- --dir "$cli_dir"; then
      ensure_on_path agy "$cli_dir/agy"
    else
      warn "Antigravity CLI install failed."
      failed=1
    fi
  fi

  return "$failed"
}
