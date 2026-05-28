FROM archlinux:latest
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        archiso \
        git \
    && pacman -Scc --noconfirm
COPY . /build
WORKDIR /build
