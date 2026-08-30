# Isolated test environment for DesktopDesigner (see ../../docs/).
# Renders nested inside the HOST's real niri session via a mounted Wayland
# socket (niri auto-picks its winit/nested backend when WAYLAND_DISPLAY is
# already set — no DRM/GPU passthrough needed), while everything else
# (packages, configs, PAM, systemd units) stays fully contained and can
# never touch the host's real dotfiles or lock screen.
FROM archlinux:base

# archlinux:base's default mirrorlist (geo.mirror.pkgbuild.com / fastly.mirror.pkgbuild.com)
# timed out repeatedly on the first build attempt. This host is Arch too and
# already has a working, fast mirrorlist — reuse it instead of debugging the
# generic one.
COPY mirrorlist /etc/pacman.d/mirrorlist

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        niri quickshell \
        qt6-base qt6-declarative qt6-svg qt6-multimedia qt6-5compat \
        alacritty tmux fuzzel mako ttf-dejavu wtype \
        networkmanager bluez \
        rust cargo \
        sudo which git \
    && pacman -Scc --noconfirm

# Non-root user matching the host UID/GID (passed at build time) so the
# mounted Wayland socket's permissions line up without chmod hacks.
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} tester && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV NIRI_CONFIG=/workspace/temp/docker/test-config.kdl

CMD ["bash"]
