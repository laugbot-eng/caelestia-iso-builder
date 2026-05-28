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
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
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
PACMAN

# ── Paquetes ────────────────────────────────────────────────
mkdir -p "$ISO_DIR/airootfs/root"

cat > "$ISO_DIR/packages.x86_64" <<'PACKAGES'
# ── Base ──
base
base-devel
linux
linux-firmware
amd-ucode
intel-ucode
syslinux
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
PACKAGES

# ── Syslinux BIOS config ────────────────────────────────────
mkdir -p "$ISO_DIR/syslinux"

cat > "$ISO_DIR/syslinux/syslinux.cfg" <<'SYSCFG'
DEFAULT select

LABEL select
COM32 whichsys.c32
APPEND -pxe- pxe -sys- sys -iso- sys

LABEL pxe
CONFIG archiso_pxe.cfg

LABEL sys
CONFIG archiso_sys.cfg
SYSCFG

cat > "$ISO_DIR/syslinux/archiso_sys.cfg" <<'SYSSYS'
INCLUDE archiso_head.cfg

DEFAULT arch
TIMEOUT 150

INCLUDE archiso_sys-linux.cfg

INCLUDE archiso_tail.cfg
SYSSYS

cat > "$ISO_DIR/syslinux/archiso_sys-linux.cfg" <<'SYSLNX'
LABEL arch
TEXT HELP
Boot Caelestia Linux live on BIOS.
ENDTEXT
MENU LABEL Caelestia Linux (%ARCH%, BIOS)
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% quiet splash

# Accessibility boot option
LABEL archspeech
TEXT HELP
Boot Caelestia Linux on BIOS with speakup screen reader.
ENDTEXT
MENU LABEL Caelestia Linux (%ARCH%, BIOS) with ^speech
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% accessibility=on
SYSLNX

cat > "$ISO_DIR/syslinux/archiso_pxe.cfg" <<'PXESYS'
INCLUDE archiso_head.cfg

INCLUDE archiso_pxe-linux.cfg

INCLUDE archiso_tail.cfg
PXESYS

cat > "$ISO_DIR/syslinux/archiso_pxe-linux.cfg" <<'PXELNX'
LABEL arch_nbd
TEXT HELP
Boot Caelestia Linux using NBD.
ENDTEXT
MENU LABEL Caelestia Linux (%ARCH%, NBD)
LINUX ::/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD ::/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% archiso_nbd_srv=${pxeserver}
SYSAPPEND 3

LABEL arch_nfs
TEXT HELP
Boot Caelestia Linux using NFS.
ENDTEXT
MENU LABEL Caelestia Linux (%ARCH%, NFS)
LINUX ::/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD ::/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archiso_nfs_srv=${pxeserver}:/run/archiso/bootmnt
SYSAPPEND 3

LABEL arch_http
TEXT HELP
Boot Caelestia Linux using HTTP.
ENDTEXT
MENU LABEL Caelestia Linux (%ARCH%, HTTP)
LINUX ::/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD ::/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archiso_http_srv=http://${pxeserver}/
SYSAPPEND 3
PXELNX

# ── EFI systemd-boot entries ────────────────────────────────
mkdir -p "$ISO_DIR/efiboot/loader/entries"

cat > "$ISO_DIR/efiboot/loader/loader.conf" <<'LOADER'
default caelestia
timeout 3
console-mode max
editor no
LOADER

cat > "$ISO_DIR/efiboot/loader/entries/caelestia.conf" <<'ENTRY'
title   Caelestia Linux
linux   /%INSTALL_DIR%/boot/vmlinuz-linux
initrd  /%INSTALL_DIR%/boot/intel-ucode.img
initrd  /%INSTALL_DIR%/boot/amd-ucode.img
initrd  /%INSTALL_DIR%/boot/initramfs-linux.img
options archisobasedir=%INSTALL_DIR% archisolabel=%ISO_LABEL% quiet splash
ENTRY

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
