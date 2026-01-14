# Grafana Dashboard - WANGuard DDoS Monitoring

Dashboard completo para visualização de métricas do WANGuard exporter.

## Features do Dashboard

### Painéis Principais

1. **API Status** (Stat)
   - Status da conexão com WANGuard API (UP/DOWN)
   - Alerta visual (verde=up, vermelho=down)

2. **License Expiration** (Stat)
   - Tempo restante de licença em segundos
   - Cores: vermelho (<24h), laranja (<7d), amarelo (<30d), verde (>30d)

3. **Active Anomalies** (Stat)
   - Número de anomalias DDoS ativas no momento
   - Cores: verde (0), vermelho (>0)

4. **Total Anomalies** (Timeseries)
   - Histórico de anomalias detectadas (acumulado)

5. **Traffic - Packets/sec** (Timeseries)
   - Pacotes IN/OUT por segundo
   - Média e máximo na legenda

6. **Traffic - Bytes/sec** (Timeseries)
   - Bytes IN/OUT por segundo
   - Conversão automática para KB/MB/GB

7. **Sensor CPU Usage** (Timeseries)
   - CPU de cada sensor (0-100%)
   - Alertas: amarelo (>70%), vermelho (>90%)

8. **Sensor RAM Usage** (Timeseries)
   - Memória RAM de cada sensor
   - Conversão automática de MB para GB

9. **Sensor Load** (Timeseries)
   - Load de cada sensor (0-100%)

10. **Top 10 Protocols** (Pie chart)
    - Protocolos com mais tráfego (TCP, UDP, ICMP, etc)

11. **Top 10 Countries** (Pie chart)
    - Países com mais tráfego

12. **Active Anomalies Table** (Table)
    - Lista de anomalias ativas em tempo real
    - Colunas: ID, Prefix, Anomaly, Duration, Pkts/s, Bits/s

13. **Component Status Table** (Table)
    - Status de todos os componentes (sensors, filters, BGP connectors)
    - Cores: verde (UP), vermelho (DOWN)

## Importação do Dashboard

### Método 1: Via UI (Recomendado)

1. Acesse Grafana: `http://localhost:3000`
2. Login: `admin` / `admin` (ou suas credenciais)
3. Menu → Dashboards → Import
4. Click em "Upload JSON file"
5. Selecione: `docker/grafana-dashboard-wanguard.json`
6. Configure:
   - **Name**: WANGuard DDoS Monitoring
   - **Folder**: General (ou crie uma pasta "Security")
   - **Datasource**: Selecione seu Prometheus datasource
7. Click "Import"

### Método 2: Via docker-compose (Automático)

Adicione ao seu `docker-compose.yml`:

```yaml
services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./docker/grafana-dashboard-wanguard.json:/etc/grafana/provisioning/dashboards/wanguard.json
      - ./docker/grafana-provisioning.yml:/etc/grafana/provisioning/dashboards/provisioning.yml
    restart: unless-stopped

volumes:
  grafana-storage:
```

Crie `docker/grafana-provisioning.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'WANGuard'
    orgId: 1
    folder: 'Security'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

Reinicie o stack:
```bash
docker-compose down
docker-compose up -d
```

### Método 3: Via API (Automático)

```bash
# Importar dashboard via API
curl -X POST \
  -H "Content-Type: application/json" \
  -d @docker/grafana-dashboard-wanguard.json \
  http://admin:admin@localhost:3000/api/dashboards/db
```

## Configuração do Datasource Prometheus

Se o datasource não existir, crie primeiro:

### Via UI
1. Menu → Configuration → Data Sources → Add data source
2. Selecione "Prometheus"
3. Configure:
   - **Name**: prometheus
   - **URL**: `http://prometheus:9090` (se usando docker-compose)
   - **URL**: `http://localhost:9090` (se Prometheus local)
4. Click "Save & Test"

### Via API
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "name": "prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }' \
  http://admin:admin@localhost:3000/api/datasources
```

## Verificação Pós-Importação

### 1. Verificar Métricas Disponíveis

No Grafana, vá em "Explore" e teste queries:

```promql
# API health
wanguard_api_up

# License
wanguard_license_seconds_remaining

# Anomalies
wanguard_anomalies_active
wanguard_anomalies_finished

# Traffic
sum(wanguard_sensor_packets_per_second_in)
sum(wanguard_sensor_bytes_per_second_in)
```

### 2. Verificar Coleta de Dados

```bash
# Verificar se Prometheus está scraping o exporter
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="wanguard-metrics")'
```

**Resultado esperado**:
```json
{
  "discoveredLabels": {...},
  "labels": {
    "instance": "localhost:9868",
    "job": "wanguard-metrics"
  },
  "scrapePool": "wanguard-metrics",
  "scrapeUrl": "http://localhost:9868/metrics",
  "health": "up",
  "lastError": "",
  "lastScrape": "2025-01-14T...",
  "lastScrapeDuration": 0.123,
  "scrapeInterval": "30s",
  "scrapeTimeout": "10s"
}
```

### 3. Verificar Dados no Dashboard

Abra o dashboard e confirme:
- ✅ "API Status" mostra "UP" (verde)
- ✅ "License Expiration" mostra tempo restante
- ✅ Gráficos de tráfego mostram dados (se houver tráfego)
- ✅ Sensores aparecem na tabela de componentes

## Troubleshooting

### Problema: Dashboard vazio (sem dados)

**Diagnóstico**:
```bash
# 1. Verificar se exporter está expondo métricas
curl -s http://localhost:9868/metrics | grep wanguard_api_up

# 2. Verificar se Prometheus está coletando
curl -s http://localhost:9090/api/v1/query?query=wanguard_api_up

# 3. Verificar logs do Prometheus
docker logs prometheus | grep wanguard
```

**Soluções**:
1. Se exporter não responde → Verificar container: `docker ps | grep wanguard_exporter`
2. Se Prometheus não coleta → Verificar `prometheus.yml` tem job `wanguard-metrics`
3. Se dados atrasados → Ajustar `scrape_interval` para 15s no Prometheus

### Problema: "No data" em painéis específicos

**Causa**: Coletor desabilitado ou API não retorna dados.

**Verificação**:
```bash
# Ver quais métricas estão disponíveis
curl -s http://localhost:9868/metrics | grep -E '^wanguard_' | cut -d'{' -f1 | sort -u
```

**Exemplo**: Se faltam métricas de `wanguard_firewall_rules_*`:
- Normal se você desabilitou: `-collector.firewall_rules=false`
- Remova os painéis de firewall do dashboard ou habilite o coletor

### Problema: Erro "Bad Gateway" ao acessar Grafana

**Diagnóstico**:
```bash
docker logs grafana
```

**Soluções**:
1. Container parado → `docker-compose up -d grafana`
2. Porta 3000 em uso → Mudar porta no docker-compose: `"3001:3000"`

### Problema: Datasource "prometheus" não encontrado

**Solução**:
1. Editar dashboard JSON antes de importar:
   - Substituir `"uid": "prometheus"` por `"uid": "YOUR_DATASOURCE_UID"`
2. Ou após importar:
   - Dashboard Settings → Variables → Datasource → Selecionar manualmente

## Customizações Recomendadas

### 1. Adicionar Alertas

Configure alertas para métricas críticas:

**Alerta: API Down**
```yaml
- alert: WANGuardAPIDown
  expr: wanguard_api_up == 0
  for: 2m
  annotations:
    summary: "WANGuard API unreachable for 2 minutes"
```

**Alerta: Licença Expirando**
```yaml
- alert: WANGuardLicenseExpiring
  expr: wanguard_license_seconds_remaining < 86400
  annotations:
    summary: "WANGuard license expires in <24h"
```

**Alerta: Anomalia Ativa**
```yaml
- alert: WANGuardDDoSAnomaly
  expr: wanguard_anomalies_active > 0
  for: 1m
  annotations:
    summary: "DDoS anomaly detected: {{ $labels.prefix }}"
```

### 2. Adicionar Variáveis

Para filtrar por sensor:

1. Dashboard Settings → Variables → Add variable
2. Configure:
   - **Name**: sensor
   - **Type**: Query
   - **Query**: `label_values(wanguard_sensor_cpu, sensor_name)`
   - **Multi-value**: Yes
3. Use nos painéis: `wanguard_sensor_cpu{sensor_name=~"$sensor"}`

### 3. Adicionar Anotações

Marque eventos importantes no dashboard:

1. Dashboard Settings → Annotations → Add annotation query
2. Configure:
   - **Name**: Anomalies
   - **Data source**: Prometheus
   - **Query**: `changes(wanguard_anomalies_finished[5m]) > 0`
3. Anomalias aparecerão como linhas verticais nos gráficos

### 4. Ajustar Refresh Rate

Para monitoramento em tempo real:
1. Dashboard → Settings → Time options
2. Configure:
   - **Refresh**: `10s` (ao invés de 30s)
   - **Time range**: `Last 15 minutes`

## Métricas Disponíveis por Coletor

### ✅ License (Habilitado)
- `wanguard_license_seconds_remaining`
- `wanguard_license_sensors_*`
- `wanguard_license_dpdk_engines_*`

### ✅ Announcements (Habilitado)
- `wanguard_announcements_active`
- `wanguard_announcements_finished`

### ✅ Anomalies (Habilitado)
- `wanguard_anomalies_active`
- `wanguard_anomalies_finished`

### ✅ Components (Habilitado)
- `wanguard_component_status`

### ✅ Sensors (Habilitado)
- `wanguard_sensor_packets_per_second_*`
- `wanguard_sensor_bytes_per_second_*`
- `wanguard_sensor_cpu`
- `wanguard_sensor_ram`
- `wanguard_sensor_load`

### ✅ Traffic (Habilitado)
- `wanguard_traffic_country_*`
- `wanguard_traffic_ip_protocol_*`
- `wanguard_traffic_talkers_*`

### ❌ Firewall Rules (Desabilitado)
- `wanguard_firewall_rules_active` (não disponível)
- `wanguard_firewall_rules_activated` (não disponível)

## Exemplos de Queries Úteis

### Top 10 IPs Atacantes (durante anomalia)
```promql
topk(10, sum by (ip_address) (wanguard_traffic_talkers_packets_per_second_in))
```

### Taxa de Pacotes Descartados
```promql
sum(rate(wanguard_sensor_dropped_in[5m]))
```

### Uso de Banda por Protocolo
```promql
sum by (ip_protocol) (wanguard_traffic_ip_protocol_bytes_per_second_in) * 8
```

### Anomalias por Hora (últimas 24h)
```promql
increase(wanguard_anomalies_finished[1h])
```

## Referências

- Dashboard JSON: `docker/grafana-dashboard-wanguard.json`
- Prometheus config: `docker/prometheus.yml`
- Exporter metrics: `http://localhost:9868/metrics`
- Grafana docs: https://grafana.com/docs/grafana/latest/dashboards/
