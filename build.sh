#!/bin/bash
# ============================================================
# Caelestia Linux ISO Builder — Build Script
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Caelestia Linux ISO Builder          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Verificar Docker
if ! command -v docker &>/dev/null; then
    echo -e "${RED}Error: Docker no está instalado.${NC}"
    echo "Instálalo desde: https://docs.docker.com/engine/install/"
    exit 1
fi

echo -e "${YELLOW}[1/2]${NC} Construyendo imagen Docker..."
docker build -t caelestia-builder -f- . <<'DOCKERFILE'
FROM archlinux:latest
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        archiso \
        git \
    && pacman -Scc --noconfirm
COPY . /build
WORKDIR /build
DOCKERFILE

echo -e "${YELLOW}[2/2]${NC} Generando ISO (esto toma 10-20 minutos)..."
docker run --rm --privileged \
    -v "$SCRIPT_DIR/output:/build/output" \
    caelestia-builder \
    bash /build/scripts/build-in-docker.sh

echo ""
echo -e "${GREEN}✅ ¡ISO generada!${NC}"
echo "   Archivo: $SCRIPT_DIR/output/caelestia-linux-$(date +%Y%m%d).iso"
ls -lh "$SCRIPT_DIR/output/"*.iso 2>/dev/null || echo "   (revisa la carpeta output/)"
