#!/usr/bin/env bash
#
# Full system bootstrap for ArchLinuxNewConfig — installs the underlying
# Arch system (yay, Homebrew, git identity, core apps, dev tooling, NVIDIA,
# SDDM, Niri + noctalia, desktop services, dotfiles, Firefox
# customizations, login theme, lock screen, ble.sh) that the repo root's own
# setup.sh (the quickshell-lock/terminal-clock extras installer) assumes
# already exists.
#
# Forked from linux_conf-main/Full-Setup/arch/setup.sh — same modular
# runner, same modules/lib, minus modules/26-dankmaterialshell.sh: this repo
# installs noctalia as DMS's replacement (see modules/16-niri.sh), so
# DankMaterialShell itself is deliberately never installed here.
#
# Modular & dynamic: every file in modules/ is a self-contained step that
# defines MODULE_DESC and a module_step() function. This script just sources
# them in filename order and runs each one — drop in a new NN-name.sh file
# and it's picked up automatically, no edits needed here.
#
# Resilient: one module failing (AUR outage, network blip, changed URL,
# etc.) logs a warning and the script keeps going instead of dying halfway
# through. Safe to re-run any time — every module skips work already done.
#
# Usage: ./setup.sh
#
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if ! command -v pacman &>/dev/null; then
  err "pacman not found — this script is for Arch Linux only."
  exit 1
fi

TMPDIR="$(mktemp -d)"
export TMPDIR

# Every failed step's captured output lands here, in one place, so you can
# fix things up after an unattended run without having to scroll back
# through terminal history. Starts empty each run; removed at the end if
# nothing failed.
ERROR_LOG="$SCRIPT_DIR/errors.log"
: > "$ERROR_LOG"

# Ask for the sudo password once up front, then keep the credential alive
# in the background for the whole run so a long unattended install (AUR
# builds especially) doesn't stall on a re-prompt with no one watching.
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" &>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!

trap 'kill "$SUDO_KEEPALIVE_PID" &>/dev/null || true; rm -rf "$TMPDIR"' EXIT

banner

shopt -s nullglob
module_files=("$MODULES_DIR"/*.sh)
shopt -u nullglob

if [ "${#module_files[@]}" -eq 0 ]; then
  err "No modules found in $MODULES_DIR — nothing to do."
  exit 1
fi

total_modules="${#module_files[@]}"
idx=0
run_start="$SECONDS"

for module in "${module_files[@]}"; do
  idx=$((idx + 1))

  # shellcheck source=/dev/null
  source "$module"

  if ! declare -f module_step &>/dev/null; then
    warn "Skipping $(basename "$module") — it doesn't define module_step()."
    continue
  fi

  step_name="${MODULE_DESC:-$(basename "$module")}"
  echo -e "\n${C_DIM}[$idx/$total_modules]${C_RESET} ${C_BOLD}${C_CYAN}${step_name}${C_RESET}"

  before_failures="${#FAILED_STEPS[@]}"
  step_start="$SECONDS"
  run_step "$step_name" module_step
  step_elapsed=$(( SECONDS - step_start ))

  if [ "${#FAILED_STEPS[@]}" -eq "$before_failures" ]; then
    ok "${step_name} ${C_DIM}($(format_duration "$step_elapsed"))${C_RESET}"
  fi

  # Unset so a module that forgets to define one of these can't silently
  # reuse the previous module's leftovers.
  unset -f module_step
  unset MODULE_DESC
done

total_elapsed=$(( SECONDS - run_start ))
succeeded=$(( total_modules - ${#FAILED_STEPS[@]} ))

echo
if [ "${#FAILED_STEPS[@]}" -eq 0 ]; then
  rm -f "$ERROR_LOG"
  summary_box "${C_BOLD}${C_GREEN}" \
    "✓ All $total_modules/$total_modules steps completed" \
    "Total time: $(format_duration "$total_elapsed")"
  echo -e "${C_DIM}System bootstrap done. Now run ../setup.sh from the repo root${C_RESET}"
  echo -e "${C_DIM}for the optional extras: quickshell-lock/terminal-clock.${C_RESET}"
else
  summary_lines=("⚠ $succeeded/$total_modules steps completed" "Total time: $(format_duration "$total_elapsed")" "" "Needs another look:")
  for s in "${FAILED_STEPS[@]}"; do
    summary_lines+=("  ✖ $s")
  done
  summary_box "${C_BOLD}${C_YELLOW}" "${summary_lines[@]}"
  echo -e "${C_DIM}Failed steps were rolled back — nothing was left half-installed.${C_RESET}"
  echo -e "${C_DIM}Full error details: ${C_RESET}${C_BOLD}$ERROR_LOG${C_RESET}"
  echo -e "${C_DIM}Re-run this script any time — it's safe and will skip what's already done.${C_RESET}"
fi
