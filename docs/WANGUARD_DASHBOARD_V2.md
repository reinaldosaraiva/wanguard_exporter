# WANGuard Dashboard V2 - Anti-DDoS NOC Dashboard

## Overview

Dashboard Grafana otimizado para operacao NOC/RCC anti-DDoS, com foco em
visibilidade imediata de ataques ativos ao abrir o dashboard.

Solicitado por Luiz Fagner (ISRE-NET) para que o time RCC consiga visualizar
alertas DDoS ativos diretamente no Grafana, sem precisar acessar o console WANGuard.

## Mudancas Implementadas

### 1. BGP Connector Collector (novo)

Arquivo: `collectors/bgp_collector.go`

Metrica exposta: `wanguard_bgp_connector_up`

| Label | Descricao | Exemplo |
|-------|-----------|---------|
| connector_name | Nome do connector | se1-bl0-rtbh |
| connector_id | ID numerico | 1 |
| connector_role | Funcao (Mitigation/Diversion) | Mitigation |
| device_group | Grupo de dispositivo | br-se1-bl0 |
| flowspec | Status FlowSpec | Disabled |

Valores: `1` = Active, `0` = Down

Fluxo de coleta:
1. GET `/bgp_connectors` - lista todos os connectors
2. GET `/bgp_connectors/{id}` - detalhe (role, device_group, flowspec)
3. GET `/bgp_connectors/{id}/status` - status operacional

Flag de controle: `--collector.bgp` (default: true)

### 2. Anomaly Labels Enriquecidos

Arquivo: `collectors/anomalies_collector.go`

6 labels adicionados a metrica `wanguard_anomaliesactive`:

| Label | Descricao | Origem API |
|-------|-----------|------------|
| severity | Nivel de severidade do ataque | severity |
| direction | Direcao (Incoming/Outgoing) | direction |
| ip_group | Grupo IP afetado | ip_group |
| decoder | Tipo do ataque (ICMP, UDP, TCP) | decoder.decoder_name |
| sensor | Interface do sensor que detectou | sensor.sensor_interface_name |
| response | Response policy ativada | response.response_name |

### 3. Dashboard Grafana Reorganizado

Layout do dashboard (de cima para baixo):

```
+--------------------------------------------------+
| Active Anomalies (row)                           |
|   Active Anomalies Details (table, full width)   |
|   Colunas: ID, Prefix, Anomaly, Sensor Interface|
|            Severity, Duration, Pkts/s, Bits/s    |
+--------------------------------------------------+
| Overview (row)                                   |
|   API Status | License | Total Anomalies |       |
|   Licensed Sensors | Sensors Used | Version      |
+--------------------------------------------------+
| License Extended (row)                           |
| Sensor Extended Metrics (row)                    |
| Traffic Overview (row)                           |
| Traffic Analysis - Bytes IN/OUT (rows)           |
| Traffic Analysis - Packets IN/OUT (rows)         |
| Sensor Performance (row)                         |
| Component Status (row)                           |
|   Component Status (table) | BGP Connectors     |
| Per-Sensor Traffic (row)                         |
|   Aggregated Sensors Traffic                     |
+--------------------------------------------------+
```

Mudancas no layout:
- Active Anomalies movido para TOPO do dashboard (primeira coisa visivel)
- Removidos paineis "Active Anomalies Count" e "Total Anomalies Finished" (redundantes)
- Removida secao "Mitigation Status (BGP Connectors)" (redundante com Component Status)
- Tabela Active Anomalies Details agora inclui colunas Sensor Interface e Severity

### 4. Correcoes de Testes Pre-existentes

| Arquivo | Bug | Fix |
|---------|-----|-----|
| 8 test files | `os.Getenv("VAR", false)` - arity errada | `os.Getenv("VAR")` |
| 8 test files | `wgc.NewClient(url, "u", "p")` - faltava arg | `wgc.NewClient(url, "u", "p", false)` |
| client/wg_client_test.go | `func TestNewClient(t *testing.T, false)` | `func TestNewClient(t *testing.T)` |
| sensors_collector_test.go | Channel buffer 1, 13 descriptors = deadlock | Buffer 20, expected 13 |
| traffic_collector_test.go | Expected 20 descriptors, actual 16 | Expected 16 |
| collector_test.go | Sem Content-Type header | jsonMiddleware wrapper |

## Deployment

### Sites Ativos

| Site | Hostname | Sensores | BGP Connectors |
|------|----------|----------|----------------|
| SE1 | se1gre0-wgexporter-1001 | br-se1-bl0, br-se1-ye0, br-se1-gr0 | 6 (3 RTBH + 3 Scrubbing) |
| NE1 | ne1yel0-wgexporter-1001 | ne1-ye0-rt-br-01, ne1-ye0-rt-br-02 | 4 (2 RTBH + 2 Scrubbing) |

### Processo de Deploy

1. Cross-compile: `GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o wanguard_exporter .`
2. SCP binario + dashboard JSON para servidor
3. Build imagem Docker com Dockerfile minimo (alpine + binario)
4. Recriar container exporter (`docker stop/rm/run`)
5. Copiar dashboard para grafana-provisioning/dashboards/
6. Restart Grafana

### Notas por Site

- **SE1**: Usa `docker compose` (plugin v2). Dashboard filtra `br-se1.*`
- **NE1**: Usa `docker-compose` v1.29.2 (tem bug ContainerConfig, usar `docker run` direto). Dashboard filtra `ne1.*`

## Metricas Disponiveis

Total de metricas wanguard_ por site:
- SE1: ~615 metricas
- NE1: ~470 metricas

Categorias:
- `wanguard_anomaliesactive` - Anomalias DDoS ativas (com labels enriquecidos)
- `wanguard_bgp_connector_up` - Status BGP connectors
- `wanguard_sensorbytes_per_second_{in,out}` - Trafego por sensor
- `wanguard_sensorpackets_per_second_{in,out}` - Pacotes por sensor
- `wanguard_componentstatus` - Status componentes WANGuard
- `wanguard_license_*` - Informacoes de licenca
- `wanguard_sensor*` - Metricas estendidas dos sensores
- `wanguard_firewall_rule_*` - Regras de firewall (desabilitado em prod)

## Aprendizados

### Docker

1. **`docker compose restart` NAO usa imagem nova** - apenas reinicia o container com a mesma imagem. Para usar imagem nova, fazer `down` + `up` ou `stop/rm/run`.

2. **docker-compose v1.29.2 tem bug com ContainerConfig** - ao tentar recriar container com imagem nova construida pelo legacy builder, da `KeyError: 'ContainerConfig'`. Workaround: usar `docker stop/rm/run` diretamente.

3. **Cross-compile e mais rapido que build no servidor** - compilar localmente com `GOOS=linux GOARCH=amd64` e enviar o binario pronto evita instalar Go no servidor e e significativamente mais rapido.

### WANGuard API

4. **Nested objects na API** - campos como `decoder`, `sensor`, `response` retornam objetos aninhados, nao strings simples. Necessario structs aninhadas no Go.

5. **BGP connector status requer 3 chamadas** - lista -> detalhe -> status. A API nao retorna tudo em uma unica chamada.

6. **Endpoints retornam 204/404 em condicoes normais** - `/announcements` retorna 204 quando vazio, nao e erro. Os logs de 404 sao pre-existentes e nao indicam problema.

### Grafana

7. **Dashboard provisioning e read-only** - dashboards provisionados via arquivo JSON nao podem ser salvos via UI. Toda mudanca deve ser no JSON e restart do Grafana.

8. **Lazy loading de paineis** - Grafana so renderiza paineis visiveis no viewport. Screenshots full-page podem mostrar paineis vazios.

9. **Filtros de sensor sao site-specific** - regex como `br-se1.*` deve ser ajustado por site. Cada instancia do dashboard precisa refletir os sensores locais.

### Testes

10. **Testes com channel buffering** - ao testar `Describe()` de collectors Prometheus, o channel precisa buffer suficiente para todos os descriptors ou ocorre deadlock.

11. **Content-Type e validado pelo client** - o WG client valida `application/json` no response. Test servers precisam setar o header.

## Proximos Passos

### Curto Prazo

- [ ] Parametrizar regex do sensor no dashboard via variavel Grafana (template variable)
  para eliminar necessidade de customizacao manual por site
- [ ] Adicionar alerting rules no Prometheus para anomalias ativas
  (`wanguard_anomaliesactive > 0` por mais de X minutos)
- [ ] Adicionar alerting para BGP connectors down
  (`wanguard_bgp_connector_up == 0`)
- [ ] Fazer commit e push das correcoes de testes e novo collector

### Medio Prazo

- [ ] Implementar collector de Response actions (metricas de mitigacao ativa)
- [ ] Adicionar metricas de latencia de scrape da API WANGuard
- [ ] Dashboard de Attack Analytics: top prefixes atacados, distribuicao por
  decoder/severity, timeline de ataques
- [ ] Unificar dashboards de multiplos sites em unico Grafana com datasource
  por site (usando Prometheus remote_write ou federation)

### Longo Prazo

- [ ] Migrar docker-compose v1 para v2 no NE1
- [ ] CI/CD pipeline para build e deploy automatico do exporter
- [ ] Helm chart para deploy em Kubernetes
- [ ] Integracao com PagerDuty/OpsGenie para alertas criticos
