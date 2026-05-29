#!/bin/bash
# ============================================================
# Build script — usa el perfil releng de archiso como base
# ============================================================
set -euo pipefail

ISO_NAME="caelestia-linux-$(date +%Y%m%d)"
OUTPUT_DIR="/build/output"
PROFILE_DIR="/tmp/archlive-${ISO_NAME}"

mkdir -p "$OUTPUT_DIR"

# ── Copiar perfil releng como base ──────────────────────────
cp -r /usr/share/archiso/configs/releng/ "$PROFILE_DIR"

# ── Personalizar profiledef.sh ──────────────────────────────
cat > "$PROFILE_DIR/profiledef.sh" <<'PROFILE'
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="caelestia-linux"
iso_label="CAELESTIA_$(date +%Y%m)"
iso_publisher="Caelestia Linux <https://github.com/laugbot-eng/caelestia-iso-builder>"
iso_application="Caelestia Linux Live"
iso_version="$(date +%Y.%m)"
install_dir="arch"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
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

# ── Personalizar paquetes ───────────────────────────────────
cat > "$PROFILE_DIR/packages.x86_64" <<'PACKAGES'
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

# ── Añadir caelestia-shell ──────────────────────────────────
mkdir -p "$PROFILE_DIR/airootfs/usr/local/bin"

cat > "$PROFILE_DIR/airootfs/usr/local/bin/caelestia-shell" <<'CSHELL'
#!/bin/bash
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
chmod +x "$PROFILE_DIR/airootfs/usr/local/bin/caelestia-shell"

# ── Personalizar .bashrc ────────────────────────────────────
cat > "$PROFILE_DIR/airootfs/root/.bashrc" <<'BASHRC'
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
PS1='\[\e[0;32m\]\u@caelestia\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
fastfetch
caelestia-shell
BASHRC

# ── hostname ────────────────────────────────────────────────
echo "caelestia-linux" > "$PROFILE_DIR/airootfs/etc/hostname"

# ── Teclado español ─────────────────────────────────────────
echo "KEYMAP=es" > "$PROFILE_DIR/airootfs/etc/vconsole.conf"

# ── Construir ISO ───────────────────────────────────────────
cd /tmp
echo "=== Construyendo ISO ==="
mkarchiso -v -w /tmp/work -o "$OUTPUT_DIR" "$PROFILE_DIR" 2>&1

echo ""
echo "=== ISO generada ==="
ls -lh "$OUTPUT_DIR/"*.iso
