#!/bin/bash
# Script de teste do container Docker

set -e

VERSION=${VERSION:-1.6}
IMAGE_NAME=${IMAGE_NAME:-wanguard_exporter}

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Teste do Container Docker${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se a imagem existe
if ! docker images | grep -q "$IMAGE_NAME.*$VERSION"; then
    echo -e "${RED}Erro: Imagem $IMAGE_NAME:$VERSION não encontrada${NC}"
    echo "Execute: ./build-docker.sh"
    exit 1
fi

echo -e "${YELLOW}Testando --version...${NC}"
docker run --rm \
    --name test_wanguard_version \
    "$IMAGE_NAME:$VERSION" \
    --version

echo ""
echo -e "${YELLOW}Testando coleta de métricas (modo de teste)...${NC}"

# Criar container em background
CONTAINER_ID=$(docker run -d \
    --name test_wanguard_metrics \
    -p 9868:9868 \
    -e WANGUARD_ADDRESS=http://invalid:81 \
    -e WANGUARD_USERNAME=admin \
    -e WANGUARD_PASSWORD=test \
    "$IMAGE_NAME:$VERSION")

echo -e "${GREEN}Container iniciado: $CONTAINER_ID${NC}"

# Aguardar container iniciar
echo -e "${YELLOW}Aguardando container iniciar...${NC}"
sleep 3

# Verificar se container está rodando
if ! docker ps | grep -q "$CONTAINER_ID"; then
    echo -e "${RED}Erro: Container não está rodando${NC}"
    docker logs "$CONTAINER_ID"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}Container está rodando${NC}"

# Testar endpoint /metrics
echo ""
echo -e "${YELLOW}Testando endpoint /metrics...${NC}"
METRICS=$(curl -s http://localhost:9868/metrics)

if [ -z "$METRICS" ]; then
    echo -e "${RED}Erro: Endpoint /metrics não retornou dados${NC}"
    docker logs "$CONTAINER_ID"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}Métricas recebidas!${NC}"
echo ""
echo -e "${YELLOW}Primeiras 10 linhas das métricas:${NC}"
echo "$METRICS" | head -10

# Verificar métricas críticas
echo ""
echo -e "${YELLOW}Verificando métricas críticas...${NC}"

if echo "$METRICS" | grep -q "wanguard_api_up"; then
    echo -e "${GREEN}✓ Métrica wanguard_api_up encontrada${NC}"
else
    echo -e "${RED}✗ Métrica wanguard_api_up NÃO encontrada${NC}"
fi

if echo "$METRICS" | grep -q "go_"; then
    echo -e "${GREEN}✓ Métricas Go encontradas${NC}"
else
    echo -e "${RED}✗ Métricas Go NÃO encontradas${NC}"
fi

# Verificar logs do container
echo ""
echo -e "${YELLOW}Logs do container:${NC}"
docker logs "$CONTAINER_ID" | tail -5

# Parar e remover container
echo ""
echo -e "${YELLOW}Parando container...${NC}"
docker stop "$CONTAINER_ID" >/dev/null 2>&1
docker rm "$CONTAINER_ID" >/dev/null 2>&1

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Teste Concluído com Sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
