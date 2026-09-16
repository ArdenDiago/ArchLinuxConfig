# Build from the repo root: docker build -f docker-preview/Dockerfile -t niri-preview .
# (paths below are relative to that root — install/dotfiles/ is the single
# source of truth for the niri+noctalia config, shared with the real
# install/modules/16-niri.sh installer, not a separate copy.)
FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        niri noctalia alacritty fuzzel hyprlock mako btop kwallet \
        polkit-gnome tigervnc mesa dbus ttf-dejavu && \
    useradd -m -s /bin/bash niri

COPY install/dotfiles/niri/config.kdl install/dotfiles/niri/binds.kdl /home/niri/.config/niri/
COPY install/dotfiles/niri/sync-overview-color.sh install/dotfiles/niri/launch-btop-float.sh install/dotfiles/niri/brightness-step.sh /home/niri/.config/niri/
COPY install/dotfiles/noctalia/settings.toml /home/niri/.local/state/noctalia/settings.toml
COPY install/dotfiles/noctalia/wallpaper.jpg /home/niri/Pictures/Wallpapers/wallpaper.jpg
COPY docker-preview/entrypoint.sh /home/niri/entrypoint.sh

RUN sed -i "s|@@HOME@@|/home/niri|g" /home/niri/.local/state/noctalia/settings.toml && \
    chmod +x /home/niri/.config/niri/sync-overview-color.sh \
             /home/niri/.config/niri/launch-btop-float.sh \
             /home/niri/.config/niri/brightness-step.sh \
             /home/niri/entrypoint.sh && \
    chown -R niri:niri /home/niri

USER niri
WORKDIR /home/niri
EXPOSE 5901
ENTRYPOINT ["/home/niri/entrypoint.sh"]
