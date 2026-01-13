#!/bin/bash
# Script de validação completa da imagem Docker

set -e

VERSION=${VERSION:-1.6}
IMAGE_NAME=${IMAGE_NAME:-wanguard_exporter}

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validação Completa da Imagem Docker${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar se a imagem existe
if ! docker images | grep -q "$IMAGE_NAME.*$VERSION"; then
    echo -e "${RED}❌ Erro: Imagem $IMAGE_NAME:$VERSION não encontrada${NC}"
    echo "Execute: ./build-docker.sh"
    exit 1
fi

echo -e "${GREEN}✓ Imagem encontrada${NC}"

# Verificar arquitetura
ARCH=$(docker inspect "$IMAGE_NAME:$VERSION" | grep Architecture | awk '{print $2}' | tr -d '"')
echo -e "${GREEN}✓ Arquitetura: $(echo $ARCH | tr -d ",")${NC}"

# Verificar tamanho
SIZE=$(docker images "$IMAGE_NAME:$VERSION" --format "{{.Size}}")
echo -e "${GREEN}✓ Tamanho: $SIZE${NC}"

# Teste 1: Execução --version
echo ""
echo -e "${YELLOW}[1/8] Testando --version...${NC}"
docker run --rm --platform linux/amd64 \
    "$IMAGE_NAME:$VERSION" \
    --version > /tmp/version_test.txt 2>&1

if grep -q "Version: 1.6" /tmp/version_test.txt; then
    echo -e "${GREEN}✓ Teste 1 passou: --version funciona${NC}"
else
    echo -e "${RED}❌ Teste 1 falhou: --version não funciona${NC}"
    cat /tmp/version_test.txt
    exit 1
fi

# Teste 2: Inicialização do container
echo ""
echo -e "${YELLOW}[2/8] Testando inicialização do container...${NC}"
CONTAINER_ID=$(docker run -d --rm --platform linux/amd64 \
    --name validate_wanguard \
    -e WANGUARD_ADDRESS=http://127.0.0.1:81 \
    -e WANGUARD_USERNAME=admin \
    -e WANGUARD_PASSWORD=test \
    -p 19868:9868 \
    "$IMAGE_NAME:$VERSION")

echo -e "${GREEN}✓ Container iniciado: $CONTAINER_ID${NC}"

# Aguardar container iniciar
sleep 3

# Verificar se container está rodando
if ! docker ps | grep -q "$CONTAINER_ID"; then
    echo -e "${RED}❌ Teste 2 falhou: Container não está rodando${NC}"
    docker logs "$CONTAINER_ID" | tail -20
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}✓ Teste 2 passou: Container está rodando${NC}"

# Teste 3: Health check
echo ""
echo -e "${YELLOW}[3/8] Testando health check...${NC}"
sleep 2
HEALTH=$(docker inspect "$CONTAINER_ID" | grep '"Status"' | head -1 | awk '{print $2}' | tr -d '"')

if [ "$HEALTH" = "healthy" ]; then
    echo -e "${GREEN}✓ Teste 3 passou: Health check funcionando${NC}"
else
    echo -e "${RED}❌ Teste 3 falhou: Health check falhou (Status: $HEALTH)${NC}"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

# Teste 4: Endpoint /metrics
echo ""
echo -e "${YELLOW}[4/8] Testando endpoint /metrics...${NC}"
METRICS=$(curl -s --max-time 5 http://localhost:19868/metrics 2>&1)

if [ -z "$METRICS" ]; then
    echo -e "${RED}❌ Teste 4 falhou: Endpoint /metrics não responde${NC}"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}✓ Teste 4 passou: Endpoint /metrics responde${NC}"

# Teste 5: Métricas do Go
echo ""
echo -e "${YELLOW}[5/8] Testando métricas do Go...${NC}"

if echo "$METRICS" | grep -q "go_"; then
    echo -e "${GREEN}✓ Teste 5 passou: Métricas do Go presentes${NC}"
else
    echo -e "${RED}❌ Teste 5 falhou: Métricas do Go ausentes${NC}"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

# Teste 6: Métrica wanguard_api_up
echo ""
echo -e "${YELLOW}[6/8] Testando métrica wanguard_api_up...${NC}"

if echo "$METRICS" | grep -q "wanguard_api_up"; then
    echo -e "${GREEN}✓ Teste 6 passou: Métrica wanguard_api_up presente${NC}"
    API_UP=$(echo "$METRICS" | grep "^wanguard_api_up" | awk '{print $2}')
    echo -e "${GREEN}  wanguard_api_up = $API_UP${NC}"
else
    echo -e "${RED}❌ Teste 6 falhou: Métrica wanguard_api_up ausente${NC}"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

# Teste 7: Logs sem erros críticos
echo ""
echo -e "${YELLOW}[7/8] Verificando logs do container...${NC}"
LOGS=$(docker logs "$CONTAINER_ID" 2>&1 | tail -20)

if echo "$LOGS" | grep -q "panic\|fatal\|FATAL\|PANIC"; then
    echo -e "${RED}❌ Teste 7 falhou: Logs contêm erros críticos${NC}"
    echo "$LOGS"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
else
    echo -e "${GREEN}✓ Teste 7 passou: Sem erros críticos nos logs${NC}"
fi

# Teste 8: Parada do container
echo ""
echo -e "${YELLOW}[8/8] Testando parada do container...${NC}"
docker stop "$CONTAINER_ID" >/dev/null 2>&1

if ! docker ps | grep -q "$CONTAINER_ID"; then
    echo -e "${GREEN}✓ Teste 8 passou: Container parou com sucesso${NC}"
else
    echo -e "${RED}❌ Teste 8 falhou: Container não parou${NC}"
    docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    exit 1
fi

# Resumo
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Todos os Testes Passaram!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Resumo da Imagem:${NC}"
echo -e "${BLUE}  Nome: $IMAGE_NAME:$VERSION${NC}"
echo -e "${BLUE}  Arquitetura: $(echo $ARCH | tr -d ",")${NC}"
echo -e "${BLUE}  Tamanho: $SIZE${NC}"
echo ""
echo -e "${BLUE}Testes Validados:${NC}"
echo -e "${GREEN}  [1/8] --version${NC}"
echo -e "${GREEN}  [2/8] Inicialização${NC}"
echo -e "${GREEN}  [3/8] Health check${NC}"
echo -e "${GREEN}  [4/8] Endpoint /metrics${NC}"
echo -e "${GREEN}  [5/8] Métricas do Go${NC}"
echo -e "${GREEN}  [6/8] wanguard_api_up${NC}"
echo -e "${GREEN}  [7/8] Logs sem erros${NC}"
echo -e "${GREEN}  [8/8] Parada do container${NC}"
echo ""
echo -e "${GREEN}✅ Imagem Docker validada para produção!${NC}"

# Limpar temporários
rm -f /tmp/version_test.txt
