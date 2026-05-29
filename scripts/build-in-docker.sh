#!/bin/bash
# ============================================================
# Build script — usa el perfil releng TAL CUAL, solo personaliza
# paquetes, hostname, y añade caelestia-shell
# ============================================================
set -euo pipefail

ISO_NAME="caelestia-linux-$(date +%Y%m%d)"
OUTPUT_DIR="/build/output"
PROFILE_DIR="/tmp/archlive-${ISO_NAME}"

mkdir -p "$OUTPUT_DIR"

# ── Copiar perfil releng COMPLETO (incluyendo boot configs) ──
cp -r /usr/share/archiso/configs/releng/ "$PROFILE_DIR"

# ── SOLO cambiar profiledef.sh (nombre, etiqueta, publisher) ──
cat > "$PROFILE_DIR/profiledef.sh" <<'PROFILE'
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="caelestia-linux"
iso_label="CAELESTIA_$(date +%Y%m)"
iso_publisher="Caelestia Linux <https://github.com/laugbot-eng/caelestia-iso-builder>"
iso_application="Caelestia Linux Live"
iso_version="$(date +%Y.%m)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/caelestia-shell"]="0:0:755"
)
PROFILE

# ── Personalizar paquetes (releng + caelestia) ──────────────
cat > "$PROFILE_DIR/packages.x86_64" <<'PACKAGES'
# ── Paquetes base releng ──
alsa-utils
amd-ucode
arch-install-scripts
base
base-devel
btrfs-progs
cryptsetup
dhcpcd
diffutils
dmidecode
dosfstools
e2fsprogs
edk2-shell
efibootmgr
espeakup
exfatprogs
f2fs-tools
fatresize
fsarchiver
gptfdisk
grml-zsh-config
grub
hyperv
intel-ucode
irqbalance
iwd
kbd
keyutils
lvm2
lynx
man-db
man-pages
mdadm
memtest86+
mkinitcpio
mkinitcpio-netconf
modemmanager
mtools
nano
ndisc6
netctl
nfs-utils
nmap
ntfs-3g
openbsd-netcat
openssh
openvswitch
partclone
parted
partimage
polkit
ppp
pptpd
rp-pppoe
rsync
rxvt-unicode-terminfo
screen
sdparm
smartmontools
sof-firmware
speech-dispatcher
squashfs-tools
terminus-font
testdisk
thin-provisioning-tools
tpm2-tss
usb_modeswitch
usbutils
vim
virt-viewer
virt-what
virtualbox-guest-utils
voicename
wget
wireless-regdb
wireless_tools
wpa_supplicant
xdg-utils
xfsprogs
xl2tpd
zsh

# ── Caelestia additions ──
hyprland
waybar
wofi
dunst
polkit-kde-agent
qt5-wayland
qt6-wayland
xdg-desktop-portal-hyprland
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
pipewire
pipewire-alsa
pipewire-pulse
pipewire-jack
wireplumber
pavucontrol
bluez
bluez-utils
htop
btop
fastfetch
unzip
zip
curl
git
p7zip
ntfs-3g
exfat-utils
ttf-dejavu
ttf-liberation
ttf-jetbrains-mono-nerd
noto-fonts
noto-fonts-emoji
adobe-source-code-pro-fonts
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
