# Caelestia Linux ISO Builder 🚀

Construye una ISO **Live Linux** con **Arch Linux + Hyprland** + herramientas preconfiguradas.

## ✨ Características

- **Escritorio Hyprland** (Wayland, tileado)
- **Firefox, Kitty, Thunar, Waybar, Wofi, Dunst**
- **PipeWire** + Bluetooth
- **Teclado español**, locale `es_ES.UTF-8`
- **shell interactivo** (`caelestia-shell`) al arrancar
- **Sesión live** — no toca el disco

## 🚀 Usar en GitHub Actions (recomendado)

1. Ve a **Actions** → **Build Caelestia Linux ISO** → **Run workflow**
2. Espera 15-30 minutos
3. Descarga la ISO desde los **artifacts**

## 🐳 Usar localmente con Docker

```bash
chmod +x build.sh
./build.sh
```

La ISO aparece en `output/`.

## ⚙️ Personalizar

Edita `scripts/build-in-docker.sh` para:
- Añadir/quitar paquetes (sección `packages.x86_64`)
- Cambiar config de Hyprland
- Añadir tus propios dotfiles

## 📦 Requisitos

- **Docker** (para build local)
- O una cuenta de **GitHub** (para Actions, es gratis)
