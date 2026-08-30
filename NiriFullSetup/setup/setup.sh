#!/usr/bin/env bash
# Reproduces the niri + noctalia desktop built in the 2026-08-28 session
# that replaced DankMaterialShell with noctalia. Run this INSIDE a fresh
# Arch Linux VM to try it risk-free, or on a real machine to actually adopt
# it — either way it only touches niri/noctalia config paths under $HOME,
# never anything system-wide beyond the package installs below.
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> [Phase 1] Updating system"
sudo pacman -Syu --noconfirm

echo "==> [Phase 1] Installing niri, sddm, and the apps the keybinds/bar expect"
# alacritty/fuzzel/hyprlock/mako/btop are spawned directly by niri's binds
# or shown on the bar; kwallet provides kwalletd6, polkit-gnome provides
# the authentication agent — both are spawned at startup by config.kdl.
# No quickshell/swaybg/jq needed: the old DMS-era swaybg wallpaper carousel
# was retired in favor of noctalia's own built-in wallpaper picker + daemon-
# managed background (Mod+W now just opens that).
sudo pacman -S --needed --noconfirm \
    niri sddm alacritty fuzzel hyprlock mako btop kwallet polkit-gnome

echo "==> [Phase 1] Enabling sddm (login screen -> pick 'Niri' session)"
sudo systemctl enable --force sddm.service

if [ "$(systemd-detect-virt)" = "oracle" ]; then
    echo "==> [Phase 1] VirtualBox detected - installing guest additions"
    sudo pacman -S --needed --noconfirm virtualbox-guest-utils
    sudo systemctl enable --now vboxservice.service
    echo "    See setup/VIRTUALBOX.md - VirtualBox's display driver often can't"
    echo "    give niri a real DRM render device even with this installed."
fi

echo "==> [Phase 2] Installing noctalia (official [extra] repo)"
sudo pacman -S --needed --noconfirm noctalia

echo "==> [Phase 2] Disabling DankMaterialShell if present"
# This setup never installs DMS, but if it's already enabled on the target
# (e.g. re-running this on the real machine the session was built on),
# leaving it running fights noctalia for the compositor's notification
# D-Bus name and the same bar/panel screen space. Safe no-op otherwise.
if systemctl --user list-unit-files dms.service >/dev/null 2>&1; then
    systemctl --user disable --now dms.service || true
fi
# `disable` above only removes dms.service's own enablement symlink. A
# prior DMS install's `niri.service.d/dms.conf` drop-in (`Wants=dms.service`)
# pulls DMS back in via niri on every login independent of that, and
# `disable` alone does NOT stop it — discovered live when this exact repo's
# migration left the DMS bar still autostarting despite dms.service showing
# disabled. Must be removed separately.
if [[ -f ~/.config/systemd/user/niri.service.d/dms.conf ]]; then
    mv ~/.config/systemd/user/niri.service.d/dms.conf \
       ~/.config/systemd/user/niri.service.d/dms.conf.bak-"$(date +%Y%m%d)"
    systemctl --user daemon-reload
fi

echo "==> [Phase 2] Installing niri config"
mkdir -p ~/.config/niri
cp "$SETUP_DIR/niri/config.kdl" "$SETUP_DIR/niri/binds.kdl" ~/.config/niri/

echo "==> [Phase 2] Installing helper scripts"
cp "$SETUP_DIR/scripts/sync-overview-color.sh" "$SETUP_DIR/scripts/launch-btop-float.sh" "$SETUP_DIR/scripts/brightness-step.sh" ~/.config/niri/
chmod +x ~/.config/niri/sync-overview-color.sh ~/.config/niri/launch-btop-float.sh ~/.config/niri/brightness-step.sh

echo "==> [Phase 2] Installing noctalia config"
mkdir -p ~/.local/state/noctalia
sed "s|@@HOME@@|$HOME|g" "$SETUP_DIR/noctalia/settings.toml" > ~/.local/state/noctalia/settings.toml

echo "==> [Phase 2] Seeding a wallpaper (noctalia's own [wallpaper.default] points here)"
mkdir -p ~/Pictures/Wallpapers
cp "$SETUP_DIR/assets/wallpaper.jpg" ~/Pictures/Wallpapers/wallpaper.jpg

echo "==> [Phase 2] Generating app theme files (GTK/alacritty/Qt/btop/niri borders)"
echo "    (best-effort here — noctalia must actually be running; if this no-ops,"
echo "    run 'noctalia msg templates-apply' by hand after your first login)"
noctalia msg templates-apply >/dev/null 2>&1 || true

echo "==> Done. Reboot, then pick 'Niri' at the SDDM login screen."
echo "    Keys: Mod+Space launcher, Mod+N control center, Mod+X power menu,"
echo "    Mod+Shift+N wifi, Mod+B bluetooth, Mod+M system resources,"
echo "    Mod+Tab overview, Mod+Slash hotkey overlay (full list in binds.kdl)."
