#!/bin/bash
# Script de build Docker para multi-arquitetura

set -e

VERSION=${VERSION:-1.6}
REGISTRY=${REGISTRY:-}
IMAGE_NAME=${IMAGE_NAME:-wanguard_exporter}

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  WANGuard Exporter Docker Build${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar Docker buildx
if ! docker buildx version > /dev/null 2>&1; then
    echo -e "${RED}Erro: Docker buildx não está disponível${NC}"
    echo "Por favor, instale ou habilite Docker buildx"
    exit 1
fi

echo -e "${YELLOW}Versão:${NC} $VERSION"
echo -e "${YELLOW}Imagem:${NC} $IMAGE_NAME"
echo ""

# Criar builder se não existir
BUILDER_NAME=wanguard_builder
if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo -e "${YELLOW}Criando builder $BUILDER_NAME...${NC}"
    docker buildx create --name $BUILDER_NAME --use
    docker buildx inspect --bootstrap
fi

echo -e "${GREEN}Building para x86_64 (amd64)...${NC}"

# Buildar para amd64
if [ -n "$REGISTRY" ]; then
    FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    echo -e "${YELLOW}Pushing para: $FULL_IMAGE${NC}"
    docker buildx build \
        --platform linux/amd64 \
        --push \
        -t "$FULL_IMAGE" \
        .
else
    FULL_IMAGE="${IMAGE_NAME}:${VERSION}"
    docker buildx build \
        --platform linux/amd64 \
        --load \
        -t "$FULL_IMAGE" \
        .
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build Concluído!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Imagem:${NC} $FULL_IMAGE"
echo -e "${YELLOW}Arquitetura:${NC} linux/amd64"
echo ""

# Mostrar tamanho da imagem
echo -e "${YELLOW}Tamanho da imagem:${NC}"
docker images | grep "$IMAGE_NAME" | head -1
