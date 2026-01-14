# Migração Manual - Passo a Passo

Execute estes comandos em sequência para migrar o WANGuard Exporter para docker-compose.

## Terminal 1: Upload dos Arquivos (Mac)

```bash
cd /Users/reinaldosaraiva/workspace/projects/golang/wanguard_exporter

# Upload docker-compose.yml e .env
scp docker-compose.yml .env ubuntu@10.251.196.19:~/wanguard_exporter/

# Upload pasta docker/ (configurações Prometheus + Grafana)
scp -r docker/ ubuntu@10.251.196.19:~/wanguard_exporter/

# Upload scripts de migração
scp -r scripts/ ubuntu@10.251.196.19:~/wanguard_exporter/
```

**Senha quando solicitado**: `WV94mxHxBtcRraaXNXLn`

---

## Terminal 2: Conectar no Servidor (SSH)

```bash
ssh ubuntu@10.251.196.19
```

**Senha**: `WV94mxHxBtcRraaXNXLn`

Agora execute os comandos abaixo **NO SERVIDOR**:

---

## No Servidor SSH

### 1. Ir para o diretório do projeto

```bash
cd ~/wanguard_exporter
```

### 2. Dar permissão de execução aos scripts

```bash
chmod +x scripts/*.sh
```

### 3. CRÍTICO: Verificar logs do container atual

```bash
# Ver últimos 50 logs
sudo docker logs wanguard_exporter --tail 50

# Procurar erros críticos
sudo docker logs wanguard_exporter 2>&1 | grep -i "panic\|fatal\|error" || echo "✓ No critical errors"

# Verificar API status
sudo docker logs wanguard_exporter 2>&1 | grep wanguard_api_up | tail -1
# DEVE mostrar: wanguard_api_up{...} 1
```

**Se encontrar erros críticos (panic, fatal), NÃO continue. Corrija primeiro.**

### 4. Verificar tunnel service

```bash
# Status do tunnel
sudo systemctl status wanguard-tunnel.service

# DEVE estar "active (running)"
```

**Se tunnel não estiver rodando**:
```bash
sudo systemctl start wanguard-tunnel.service
```

### 5. Executar migração automática

```bash
sudo bash scripts/migrate-to-compose.sh
```

Este script vai:
1. ✅ Verificar tunnel service
2. ✅ Checar logs por erros
3. ✅ Criar backup do container atual
4. ✅ Parar e remover container antigo
5. ✅ Verificar/criar arquivo `.env`
6. ✅ Iniciar stack docker-compose (exporter + Prometheus + Grafana)
7. ✅ Validar serviços
8. ✅ Testar métricas

**Tempo estimado**: 2-3 minutos

---

## Validação Pós-Migração

### 1. Verificar containers rodando

```bash
sudo docker-compose ps
```

**Esperado**:
```
NAME                STATUS
wanguard_exporter   Up (healthy)
prometheus          Up (healthy)
grafana             Up (healthy)
```

### 2. Testar endpoint de métricas

```bash
# API status
curl -s http://localhost:9868/metrics | grep wanguard_api_up

# Esperado: wanguard_api_up{api_address="127.0.0.1:8081"} 1
```

### 3. Contar métricas

```bash
curl -s http://localhost:9868/metrics | grep -c "^wanguard_"

# Esperado: >20
```

### 4. Ver logs dos serviços

```bash
# Logs do exporter
sudo docker-compose logs -f wanguard-exporter

# Ctrl+C para sair

# Logs de todos os serviços
sudo docker-compose logs --tail 20
```

---

## Acessar Grafana

1. Abra no navegador: **http://10.251.196.19:3000**
2. Login: `admin` / `admin`
3. Dashboard: **WANGuard DDoS Monitoring** (já importado automaticamente!)

**Se dashboard não aparecer**:
- Menu → Dashboards → Buscar "WANGuard"

---

## Troubleshooting

### Problema: wanguard_api_up = 0

```bash
# Reiniciar tunnel
sudo systemctl restart wanguard-tunnel.service

# Reiniciar exporter
sudo docker-compose restart wanguard-exporter

# Aguardar 10 segundos e testar
sleep 10
curl -s http://localhost:9868/metrics | grep wanguard_api_up
```

### Problema: Container não inicia

```bash
# Ver logs
sudo docker-compose logs wanguard-exporter

# Verificar se imagem existe
sudo docker images | grep wanguard-exporter

# Se não existir, buildar
sudo docker build -t wanguard-exporter:final .

# Recriar container
sudo docker-compose up -d --force-recreate wanguard-exporter
```

### Problema: Grafana sem dados

```bash
# Verificar se Prometheus está coletando
curl -s "http://localhost:9090/api/v1/query?query=wanguard_api_up"

# Ver targets do Prometheus
curl -s http://localhost:9090/api/v1/targets | grep wanguard

# Reiniciar Prometheus
sudo docker-compose restart prometheus
```

---

## Comandos Úteis

```bash
# Status de todos os serviços
sudo docker-compose ps

# Logs em tempo real
sudo docker-compose logs -f

# Reiniciar tudo
sudo docker-compose restart

# Parar tudo
sudo docker-compose down

# Parar e remover volumes (CUIDADO!)
sudo docker-compose down -v

# Rebuild e restart
sudo docker-compose up -d --build
```

---

## Rollback (Se Necessário)

```bash
# Parar docker-compose
sudo docker-compose down

# Voltar ao container antigo
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

---

## Próximos Passos

1. ✅ Acessar Grafana e explorar dashboard
2. ✅ Configurar alertas (opcional)
3. ✅ Configurar backup dos volumes Prometheus/Grafana
4. ✅ Documentar credenciais em local seguro

---

## Resumo URLs

- **Exporter**: http://10.251.196.19:9868/metrics
- **Prometheus**: http://10.251.196.19:9090
- **Grafana**: http://10.251.196.19:3000 (admin/admin)
