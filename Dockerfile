# Build Stage
FROM golang:1.21.5-alpine AS builder

# Instalar dependências de build
RUN apk add --no-cache git ca-certificates

# Definir diretório de trabalho
WORKDIR /build

# Copiar go.mod e go.sum para cache de dependências
COPY go.mod go.sum ./

# Download de dependências
RUN go mod download

# Copiar código fonte
COPY . .

# Buildar com flags de otimização
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=$(cat VERSION 2>/dev/null || echo '1.6')" \
    -a \
    -installsuffix cgo \
    -o wanguard_exporter .

# Runtime Stage
FROM alpine:3.19

LABEL org.opencontainers.image.title="WANGuard Exporter"
LABEL org.opencontainers.image.description="Prometheus exporter for WANGuard with security and robustness improvements"
LABEL org.opencontainers.image.version="1.6"
LABEL org.opencontainers.image.authors="Tomas Vilemaitis"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/tomvil/wanguard_exporter"

# Instalar ca-certificates e wget para health check
RUN apk --no-cache add ca-certificates tzdata wget && \
    addgroup -g 1000 wanguard && \
    adduser -D -u 1000 -G wanguard wanguard

# Criar diretório de trabalho
WORKDIR /app

# Copiar binário do stage de build
COPY --from=builder /build/wanguard_exporter /app/

# Mudar para usuário não-root
USER wanguard

# Expor porta padrão
EXPOSE 9868

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9868/metrics || exit 1

# Comando padrão
ENTRYPOINT ["/app/wanguard_exporter"]
