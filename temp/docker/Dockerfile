# Isolated test environment for the real niri+noctalia setup (see
# ../../install/modules/16-niri.sh). Renders nested inside the HOST's real
# niri session via a mounted Wayland socket (niri auto-picks its winit/
# nested backend when WAYLAND_DISPLAY is already set — no DRM/GPU
# passthrough needed), while everything else (packages, configs) stays
# fully contained and can never touch the host's real dotfiles. No
# sddm/systemd/DMS-migration steps here — those are real-login-manager
# concerns that don't apply to a container where niri is launched directly.
FROM archlinux:base

COPY mirrorlist /etc/pacman.d/mirrorlist

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        niri noctalia \
        alacritty fuzzel hyprlock mako btop kwallet polkit-gnome \
        ttf-dejavu wtype \
        sudo which \
    && pacman -Scc --noconfirm

ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} tester && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester
ENV XDG_RUNTIME_DIR=/run/user/1000

CMD ["bash"]
