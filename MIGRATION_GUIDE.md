# Migration Guide: docker run → docker-compose

Guia completo para migrar o deployment do WANGuard Exporter para docker-compose com Prometheus + Grafana integrados.

## O Que Mudou?

### Antes (docker run)
```bash
sudo docker run -d \
  --name wanguard_exporter \
  --restart unless-stopped \
  --network host \
  wanguard-exporter:final \
  -api.address http://127.0.0.1:8081/wanguard-api/ \
  -api.username api \
  -api.password api \
  -collector.firewall_rules=false \
  -web.listen-address :9868
```

**Problemas**:
- Configuração manual, difícil de reproduzir
- Sem Prometheus integrado
- Sem Grafana para visualização
- Variáveis hardcoded no comando

### Depois (docker-compose)
```bash
docker-compose up -d
```

**Benefícios**:
- ✅ 3 serviços (exporter + Prometheus + Grafana)
- ✅ Configuração via `.env` file
- ✅ Dashboard Grafana auto-importado
- ✅ Persistent volumes (dados preservados)
- ✅ Health checks automáticos
- ✅ Log rotation configurado
- ✅ Fácil atualização e rollback

## Pré-requisitos

### 1. Verificar Logs ANTES da Migração

**CRÍTICO**: Verifique se há erros no exporter atual.

```bash
# No servidor SSH
sudo docker logs wanguard_exporter --tail 50

# Procurar por:
# - "panic" ou "fatal" → Erros críticos
# - "wanguard_api_up 0" → API connection down
# - "error" ou "ERROR" → Problemas gerais
```

**Exemplo de log saudável**:
```
level=info msg="Starting wanguard_exporter" version=...
level=info msg="Listening on :9868" address=:9868
```

**Exemplo de log com erro**:
```
level=error msg="Failed to connect to API" error="connection refused"
panic: runtime error: invalid memory address
```

### 2. Verificar Tunnel Service

```bash
# Tunnel DEVE estar rodando
sudo systemctl status wanguard-tunnel.service

# Testar conectividade
curl -s -I http://127.0.0.1:8081/wanguard-api/
# Esperado: HTTP/1.1 401 Unauthorized (ou 200 OK)
```

## Migração Automática (Recomendado)

### Passo 1: Upload dos Arquivos

**Do seu Mac**, execute:

```bash
# Na pasta wanguard_exporter
scp -r docker/ ubuntu@10.251.196.19:~/wanguard_exporter/
scp -r scripts/ ubuntu@10.251.196.19:~/wanguard_exporter/
scp docker-compose.yml ubuntu@10.251.196.19:~/wanguard_exporter/
scp .env ubuntu@10.251.196.19:~/wanguard_exporter/
```

### Passo 2: Executar Script de Migração

**No servidor SSH**:

```bash
cd ~/wanguard_exporter
sudo bash scripts/migrate-to-compose.sh
```

O script faz:
1. ✅ Verifica tunnel service
2. ✅ Checa logs por erros
3. ✅ Cria backup do container atual
4. ✅ Para e remove container antigo
5. ✅ Inicia docker-compose stack
6. ✅ Valida métricas e serviços
7. ✅ Mostra URLs de acesso

**Tempo estimado**: 2-3 minutos

## Migração Manual (Passo a Passo)

### 1. Verificar Logs (OBRIGATÓRIO)

```bash
# Salvar logs atuais
sudo docker logs wanguard_exporter --tail 100 > ~/exporter_logs_backup.txt

# Revisar logs
less ~/exporter_logs_backup.txt

# Verificar API status
sudo docker logs wanguard_exporter 2>&1 | grep wanguard_api_up
# Esperado: wanguard_api_up{...} 1
```

**Se encontrar erros**:
- `panic` ou `fatal` → NÃO migre, corrija primeiro
- `wanguard_api_up 0` → Verifique tunnel e credenciais
- Nenhum erro → Prossiga

### 2. Parar Container Atual

```bash
# Parar
sudo docker stop wanguard_exporter

# Remover
sudo docker rm wanguard_exporter

# Verificar porta livre
sudo ss -tulpn | grep 9868
# Não deve retornar nada
```

### 3. Configurar .env

```bash
cd ~/wanguard_exporter

# Se .env não existir, criar
cat > .env <<'EOF'
# WANGuard API Configuration
WANGUARD_API_ADDRESS=http://127.0.0.1:8081/wanguard-api/
WANGUARD_API_USERNAME=api
WANGUARD_API_PASSWORD=api

# Collectors Configuration
WANGUARD_DISABLED_COLLECTORS=firewall_rules

# Exporter Configuration
WANGUARD_EXPORTER_PORT=9868

# Prometheus Configuration
PROMETHEUS_PORT=9090

# Grafana Configuration
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
EOF

# Revisar
cat .env
```

### 4. Iniciar Stack

```bash
# Subir todos os serviços
sudo docker-compose up -d

# Ver logs em tempo real
sudo docker-compose logs -f

# Ctrl+C para sair
```

### 5. Verificar Serviços

```bash
# Status dos containers
sudo docker-compose ps

# Esperado:
# NAME                IMAGE                      STATUS
# wanguard_exporter   wanguard-exporter:final    Up
# prometheus          prom/prometheus:latest     Up
# grafana             grafana/grafana:latest     Up
```

### 6. Testar Métricas

```bash
# Exporter
curl -s http://localhost:9868/metrics | grep wanguard_api_up
# Esperado: wanguard_api_up{api_address="127.0.0.1:8081"} 1

# Prometheus
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[0].health'
# Esperado: "up"

# Grafana
curl -s http://localhost:3000/api/health | jq .
# Esperado: {"database":"ok","version":"..."}
```

## Verificação Pós-Migração

### 1. Check Completo

```bash
cd ~/wanguard_exporter
./scripts/verify-deployment.sh
```

### 2. Acessar Grafana

1. Abra no navegador: **http://10.251.196.19:3000**
2. Login: `admin` / `admin`
3. Dashboard: **WANGuard DDoS Monitoring** (auto-importado)

**Se dashboard não aparecer**:
- Menu → Dashboards → Import
- Upload: `docker/grafana-dashboard-wanguard.json`
- Datasource: Prometheus

### 3. Verificar Métricas no Dashboard

Confirme que os painéis mostram dados:
- ✅ **API Status**: Verde (UP)
- ✅ **License Expiration**: Tempo restante
- ✅ **Traffic**: Gráficos com dados (se houver tráfego)
- ✅ **Sensors**: CPU, RAM, Load

## Troubleshooting

### Problema: Exporter não inicia

**Diagnóstico**:
```bash
sudo docker-compose logs wanguard-exporter
```

**Soluções**:
| Erro | Causa | Fix |
|------|-------|-----|
| `connection refused` | Tunnel down | `sudo systemctl restart wanguard-tunnel.service` |
| `authentication failed` | Credenciais erradas | Corrigir `.env` |
| `address already in use` | Porta 9868 ocupada | `sudo fuser -k 9868/tcp` |
| `image not found` | Falta build | `sudo docker build -t wanguard-exporter:final .` |

### Problema: wanguard_api_up = 0

**Diagnóstico**:
```bash
# 1. Testar tunnel
curl -s -I http://127.0.0.1:8081/wanguard-api/

# 2. Verificar tunnel service
sudo systemctl status wanguard-tunnel.service

# 3. Ver logs do exporter
sudo docker-compose logs wanguard-exporter | grep -i error
```

**Fix**:
```bash
sudo systemctl restart wanguard-tunnel.service
sudo docker-compose restart wanguard-exporter
```

### Problema: Grafana sem dados

**Diagnóstico**:
```bash
# 1. Verificar datasource
curl -s http://localhost:3000/api/datasources | jq .

# 2. Testar query do Prometheus
curl -s "http://localhost:9090/api/v1/query?query=wanguard_api_up"
```

**Fix**:
1. Grafana → Configuration → Data Sources
2. Verificar se Prometheus está configurado: `http://prometheus:9090`
3. Testar conexão (botão "Save & Test")

### Problema: Containers reiniciando

**Diagnóstico**:
```bash
# Ver status
sudo docker-compose ps

# Ver logs de crash
sudo docker-compose logs --tail 50 [service-name]
```

**Soluções comuns**:
- Health check falhando → Aumentar `start_period` no docker-compose.yml
- OOM (Out of Memory) → Verificar `docker stats`, aumentar RAM
- Crash loop → Verificar logs, desabilitar mais collectors

## Rollback (Se Algo Der Errado)

### Opção 1: Restaurar Container Antigo (Rápido)

```bash
# Parar docker-compose
sudo docker-compose down

# Recriar container antigo
sudo docker run -d \
  --name wanguard_exporter \
  --restart unless-stopped \
  --network host \
  wanguard-exporter:final \
  -api.address http://127.0.0.1:8081/wanguard-api/ \
  -api.username api \
  -api.password api \
  -collector.firewall_rules=false \
  -web.listen-address :9868

# Verificar
curl -s http://localhost:9868/metrics | grep wanguard_api_up
```

### Opção 2: Restaurar do Backup

```bash
# Ver backups
ls -lh backup_*/

# Restaurar logs (para análise)
cat backup_YYYYMMDD_HHMMSS/container.log

# Recriar a partir do inspect
# (ver backup_*/container.json para comandos exatos)
```

## Comandos Úteis

### Gerenciamento

```bash
# Ver todos os serviços
sudo docker-compose ps

# Logs em tempo real
sudo docker-compose logs -f

# Logs de um serviço específico
sudo docker-compose logs -f wanguard-exporter

# Reiniciar todos
sudo docker-compose restart

# Reiniciar um serviço
sudo docker-compose restart wanguard-exporter

# Parar todos
sudo docker-compose down

# Parar e remover volumes (CUIDADO!)
sudo docker-compose down -v
```

### Atualização

```bash
# Rebuild da imagem
sudo docker build -t wanguard-exporter:final .

# Recriar apenas o exporter
sudo docker-compose up -d --force-recreate wanguard-exporter

# Pull de novas imagens
sudo docker-compose pull

# Aplicar mudanças
sudo docker-compose up -d
```

### Manutenção

```bash
# Ver uso de recursos
sudo docker stats

# Limpar logs antigos
sudo docker system prune -a

# Ver volumes
sudo docker volume ls

# Inspecionar volume
sudo docker volume inspect wanguard_exporter_prometheus-data
```

## Estrutura de Arquivos

```
wanguard_exporter/
├── .env                          # ← Configurações (NÃO commitar!)
├── docker-compose.yml            # ← Orquestração dos serviços
├── docker/
│   ├── prometheus.yml            # Config do Prometheus
│   ├── alert_rules.yml           # Alertas
│   ├── grafana-provisioning/
│   │   ├── datasources/
│   │   │   └── prometheus.yml    # Datasource auto-config
│   │   └── dashboards/
│   │       ├── wanguard.yml      # Dashboard provider
│   │       └── grafana-dashboard-wanguard.json
│   └── grafana-dashboard-wanguard.json
├── scripts/
│   ├── migrate-to-compose.sh     # Script de migração
│   └── verify-deployment.sh      # Script de verificação
└── backup_YYYYMMDD_HHMMSS/       # Backups automáticos
    ├── container.log
    └── container.json
```

## Volumes Persistentes

Os dados são preservados mesmo após `docker-compose down`:

| Volume | Conteúdo | Localização |
|--------|----------|-------------|
| `prometheus-data` | Séries temporais (30 dias) | `/var/lib/docker/volumes/wanguard_exporter_prometheus-data` |
| `grafana-data` | Dashboards, datasources, usuários | `/var/lib/docker/volumes/wanguard_exporter_grafana-data` |

**Para backup**:
```bash
# Backup Prometheus
sudo tar -czf prometheus-backup.tar.gz -C /var/lib/docker/volumes/wanguard_exporter_prometheus-data/_data .

# Backup Grafana
sudo tar -czf grafana-backup.tar.gz -C /var/lib/docker/volumes/wanguard_exporter_grafana-data/_data .
```

## Checklist de Migração

Antes de começar:
- [ ] Container atual está rodando sem erros críticos
- [ ] Tunnel service (wanguard-tunnel.service) está ativo
- [ ] Arquivos enviados para servidor (docker-compose.yml, .env, docker/, scripts/)
- [ ] Porta 9868, 9090, 3000 estão livres

Durante migração:
- [ ] Logs verificados (sem panic/fatal)
- [ ] Backup criado
- [ ] Container antigo parado e removido
- [ ] docker-compose up -d executado
- [ ] Todos os 3 serviços iniciaram (docker-compose ps)

Pós-migração:
- [ ] wanguard_api_up = 1
- [ ] Prometheus coletando métricas
- [ ] Grafana acessível
- [ ] Dashboard mostrando dados

## Referências

- Docker Compose Docs: https://docs.docker.com/compose/
- Prometheus Config: https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- Grafana Provisioning: https://grafana.com/docs/grafana/latest/administration/provisioning/

## Suporte

Se encontrar problemas:
1. Verifique logs: `sudo docker-compose logs`
2. Execute verificação: `./scripts/verify-deployment.sh`
3. Consulte: `docs/DEPLOYMENT_WORKAROUNDS.md`
4. Consulte: `SSH_COMMANDS.md`
