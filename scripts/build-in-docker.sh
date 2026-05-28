#!/bin/bash
# ============================================================
# Build script — ejecutado DENTRO del contenedor Docker
# ============================================================
set -euo pipefail

ISO_NAME="caelestia-linux-$(date +%Y%m%d)"
ISO_DIR="/tmp/archlive-${ISO_NAME}"
OUTPUT_DIR="/build/output"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$ISO_DIR"

# ── Perfil base de archiso ──────────────────────────────────
cat > "$ISO_DIR/profiledef.sh" <<'PROFILE'
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="caelestia-linux"
iso_label="CAELESTIA_$(date +%Y%m)"
iso_publisher="Caelestia Linux <https://github.com/laugbot-eng/caelestia-iso-builder>"
iso_application="Caelestia Linux Live"
iso_version="$(date +%Y.%m)"
install_dir="arch"
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.systemd-boot.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/caelestia-shell"]="0:0:755"
)
PROFILE

# ── pacman.conf ─────────────────────────────────────────────
cat > "$ISO_DIR/pacman.conf" <<'PACMAN'
[options]
ParallelDownloads = 5
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist
PACMAN

# ── Paquetes ────────────────────────────────────────────────
mkdir -p "$ISO_DIR/airootfs/root"

cat > "$ISO_DIR/packages.x86_64" <<'PACKAGES'
# ── Base ──
base
base-devel
linux
linux-firmware
sudo
vim
networkmanager
wpa_supplicant
wireless_tools
dialog

# ── Hyprland / Wayland ──
hyprland
waybar
wofi
dunst
polkit-kde-agent
qt5-wayland
qt6-wayland
xdg-desktop-portal-hyprland
xdg-utils

# ── Aplicaciones ──
kitty
firefox
thunar
thunar-archive-plugin
gvfs
gvfs-mtp
gvfs-gphoto2
gvfs-smb
ranger
nemo

# ── Audio / Bluetooth ──
pipewire
pipewire-alsa
pipewire-pulse
pipewire-jack
wireplumber
pavucontrol
bluez
bluez-utils

# ── Utilidades ──
htop
btop
neofetch
fastfetch
unzip
zip
wget
curl
git
p7zip
ntfs-3g
exfat-utils
dosfstools
man-db
man-pages
texinfo

# ── Fuentes / Tema ──
ttf-dejavu
ttf-liberation
ttf-jetbrains-mono-nerd
noto-fonts
noto-fonts-emoji
adobe-source-code-pro-fonts

# ── Herramientas extra ──
firefox-i18n-es-es
gdm
PACKAGES

# ── Configuración del sistema ───────────────────────────────
mkdir -p "$ISO_DIR/airootfs/etc"
mkdir -p "$ISO_DIR/airootfs/usr/local/bin"

# hostname
echo "caelestia-linux" > "$ISO_DIR/airootfs/etc/hostname"

# hosts
cat > "$ISO_DIR/airootfs/etc/hosts" <<'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   caelestia-linux.localdomain caelestia-linux
HOSTS

# locale
echo "es_ES.UTF-8 UTF-8" > "$ISO_DIR/airootfs/etc/locale.gen"
echo "en_US.UTF-8 UTF-8" >> "$ISO_DIR/airootfs/etc/locale.gen"
echo "LANG=es_ES.UTF-8" > "$ISO_DIR/airootfs/etc/locale.conf"

# keymap
echo "KEYMAP=es" > "$ISO_DIR/airootfs/etc/vconsole.conf"

# enable services
mkdir -p "$ISO_DIR/airootfs/etc/systemd/system/multi-user.target.wants"
cat > "$ISO_DIR/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service" <<'SVCLNK'
[Unit]
Description=Network Manager
[Service]
Type=dbus
BusName=org.freedesktop.NetworkManager
ExecStart=/usr/bin/NetworkManager --no-daemon
[Install]
WantedBy=multi-user.target
SVCLNK

# ── caelestia-shell ─────────────────────────────────────────
cat > "$ISO_DIR/airootfs/usr/local/bin/caelestia-shell" <<'CSHELL'
#!/bin/bash
# Caelestia Shell — lanzador interactivo minimalista
echo "╔══════════════════════════════════════╗"
echo "║   Caelestia Linux - $(date +%Y)              ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Bienvenido a Caelestia Linux Live."
echo "Comandos rápidos:"
echo "  hyprland  — Iniciar escritorio"
echo "  help     — Ver ayuda"
echo "  exit     — Salir"
echo ""
while true; do
    read -p "caelestia> " cmd
    case "$cmd" in
        hyprland|startx) exec Hyprland ;;
        help) echo "Comandos: hyprland, help, exit" ;;
        exit|quit) exit 0 ;;
        "") ;;
        *) echo "Comando no encontrado: $cmd" ;;
    esac
done
CSHELL
chmod +x "$ISO_DIR/airootfs/usr/local/bin/caelestia-shell"

# ── .bashrc para live ───────────────────────────────────────
cat > "$ISO_DIR/airootfs/root/.bashrc" <<'BASHRC'
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
PS1='\[\e[0;32m\]\u@caelestia\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
neofetch || fastfetch
caelestia-shell
BASHRC

# ── Sudoers ─────────────────────────────────────────────────
mkdir -p "$ISO_DIR/airootfs/etc/sudoers.d"
echo "root ALL=(ALL) ALL" > "$ISO_DIR/airootfs/etc/sudoers.d/root"
echo "live ALL=(ALL) NOPASSWD: ALL" > "$ISO_DIR/airootfs/etc/sudoers.d/live"

# ── Construir ISO ───────────────────────────────────────────
cd /tmp
echo "=== Construyendo ISO ==="
mkarchiso -v -w /tmp/work -o "$OUTPUT_DIR" "$ISO_DIR" 2>&1

echo ""
echo "=== ISO generada ==="
ls -lh "$OUTPUT_DIR/"*.iso
