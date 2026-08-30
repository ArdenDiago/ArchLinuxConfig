FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        niri noctalia alacritty fuzzel hyprlock mako btop kwallet \
        polkit-gnome tigervnc mesa dbus ttf-dejavu && \
    useradd -m -s /bin/bash niri

COPY niri/config.kdl niri/binds.kdl /home/niri/.config/niri/
COPY scripts/sync-overview-color.sh scripts/launch-btop-float.sh /home/niri/.config/niri/
COPY noctalia/settings.toml /home/niri/.local/state/noctalia/settings.toml
COPY assets/wallpaper.jpg /home/niri/Pictures/Wallpapers/wallpaper.jpg
COPY docker/entrypoint.sh /home/niri/entrypoint.sh

RUN sed -i "s|@@HOME@@|/home/niri|g" /home/niri/.local/state/noctalia/settings.toml && \
    chmod +x /home/niri/.config/niri/sync-overview-color.sh \
             /home/niri/.config/niri/launch-btop-float.sh \
             /home/niri/entrypoint.sh && \
    chown -R niri:niri /home/niri

USER niri
WORKDIR /home/niri
EXPOSE 5901
ENTRYPOINT ["/home/niri/entrypoint.sh"]
