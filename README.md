# wanguard_exporter

Prometheus exporter for Andrisoft WANGuard API with security hardening and production-ready Docker deployment.

## Quick Start (Docker - Recommended)

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Edit .env with your WANGuard credentials
nano .env

# 3. Build the Docker image
docker build -t wanguard-exporter:final .

# 4. Start the stack (exporter + prometheus + grafana + nginx)
docker-compose up -d

# 5. Verify services are running
docker-compose ps

# 6. Access the dashboards
# Grafana: http://localhost/grafana/
# Prometheus: http://localhost/prometheus/
# Metrics: http://localhost:9868/metrics
```

See [DOCKER_QUICKSTART.md](DOCKER_QUICKSTART.md) for detailed instructions.

## Architecture

```
                    +------------------+
                    |     Nginx        |
                    |   (port 80)      |
                    +--------+---------+
                             |
            +----------------+----------------+
            |                                 |
   /grafana/                         /prometheus/
            |                                 |
   +--------v---------+          +-----------v----------+
   |     Grafana      |          |     Prometheus       |
   |   (port 3000)    |          |     (port 9090)      |
   +------------------+          +-----------+----------+
                                             |
                                    scrapes metrics
                                             |
                                 +-----------v----------+
                                 | WANGuard Exporter    |
                                 |    (port 9868)       |
                                 +-----------+----------+
                                             |
                                    HTTP/HTTPS API
                                             |
                                 +-----------v----------+
                                 |   WANGuard Server    |
                                 +----------------------+
```

## Install

### Docker (Recommended)
```bash
docker pull wanguard_exporter:1.6
```

### From Source
```bash
go install github.com/tomvil/wanguard_exporter@latest
```

## Security Improvements

This fork includes security hardening based on code review analysis:

### Fixed Vulnerabilities
- **CRITICAL**: SSRF prevention via URL.ResolveReference host validation
- **HIGH**: DoS protection with io.LimitReader (10MB response limit)
- **HIGH**: HTTP blocked for remote hosts (HTTPS enforced, localhost exception)
- **MEDIUM**: Path traversal prevention using proper URL resolution
- **MEDIUM**: Prometheus label cardinality explosion mitigation

### Security Features
- TLS 1.2+ enforcement
- Secure HTTP client with timeouts (30s total, 10s TLS handshake)
- Credential leak prevention on redirects
- Input validation for API addresses
- Non-root Docker user (UID 1000)
- Read-only filesystem in Docker container

## Configuration flags
Name     | Description | Default
---------|-------------|---------
version | Print information about exporter version |
web.listen-address | Address on which to expose metrics | :9868
web.metrics-path | Path under which to expose metrics | /metrics
api.address | WANGuard API Address | 127.0.0.1:81
api.username | WANGuard API Username | admin
api.password | WANGuard API Password |
api.insecure | Allow HTTP for remote hosts and skip TLS certificate verification | false
licenseCollectorEnabled | Export license metrics | true
announcementsCollectorEnabled | Export announcements metrics | true
anomaliesCollectorEnabled | Export anomalies metrics | true
componentsCollectorEnabled | Export components metrics | true
actionsCollectorEnabled | Export actions metrics | true
sensorsCollectorEnabled | Export sensors metrics | true
trafficCollectorEnabled | Export traffic metrics | true
firewallRulesCollectorEnabled | Export firewall rules metrics | true

## Configuration environment variables
Name     | Description
---------|-------------
WANGUARD_PASSWORD | WANGuard API Password

This will be used automatically if `api.password` flag is not set.


## Usage

### Docker
```bash
# Build the image first
docker build -t wanguard-exporter:final .

# Start the stack
docker-compose up -d
```

Environment variables (in `.env`):
```env
WANGUARD_ADDRESS=http://wanguard-server:81
WANGUARD_USERNAME=admin
WANGUARD_PASSWORD=your-password
```

### Binary
```bash
# HTTPS (recommended for production)
./wanguard_exporter \
  -api.address="https://wanguard-server:81" \
  -api.username="admin" \
  -api.password="password"

# HTTP with -api.insecure (for tunneled connections or internal networks)
./wanguard_exporter \
  -api.address="http://127.0.0.1:8081/wanguard-api/" \
  -api.username="admin" \
  -api.password="password" \
  -api.insecure
```

**Note**: By default, HTTP is only allowed for localhost (127.0.0.1, ::1). Remote connections require HTTPS unless `-api.insecure` flag is set. Use `-api.insecure` only for trusted internal networks or SSH tunnels.

## Additional Documentation

- [Docker Quickstart Guide](DOCKER_QUICKSTART.md) - 3-step setup
- [Docker Deployment Guide](docs/docker/DEPLOYMENT_GUIDE.md) - Production deployment
- [Production Validation Checklist](docs/docker/PRODUCTION_VALIDATION.md)
- [Security Hardening Details](docs/security/FASE2_HTTP_CLIENT_ROBUSTO.md)

## Metrics

### API Health Metric (NEW)
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_api_up | gauge | Whether the WANGuard API is reachable (1 = up, 0 = down) | api_address

Example:
```
wanguard_api_up{api_address="wanguard-server:81"} 1
```

### License Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_license_software_version | gauge | Software version | software_version
wanguard_license_sensors_available | gauge | Licensed sensors available |
wanguard_license_sensors_used | gauge | Licensed sensors used |
wanguard_license_sensors_remaining | gauge | Licensed sensors remaining |
wanguard_license_dpdk_engines_available | gauge | Licensed DPDK engines available |
wanguard_license_dpdk_engines_used | gauge | Licensed DPDK engines used |
wanguard_license_dpdk_engines_remaining | gauge | Licensed DPDK engines remaining |
wanguard_license_filters_available | gauge | Licensed filters available |
wanguard_license_filters_used | gauge | Licensed filters used |
wanguard_license_filters_remaining | gauge | Licensed filters remaining |
wanguard_license_seconds_remaining | gauge | License seconds remaining |
wanguard_license_support_seconds_remaining | gauge | Support license seconds remaining |

Example:
```
wanguard_license_software_version{software_version="8.3-21"} 1
wanguard_license_sensors_available 1
wanguard_license_sensors_used 1
wanguard_license_sensors_remaining 0
wanguard_license_seconds_remaining 86400
```

### Announcements Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_announcements_active | gauge | Active announcements at the moment | announcement_id, bgp_connector_name, from, prefix, until
wanguard_announcements_finished | gauge | Total amount of finished announcements |

Example:
```
wanguard_announcements_active{announcement_id="1",bgp_connector_name="Connector 1",from="2024-10-23 09:31:01",prefix="10.10.10.10/32",until=""} 1
wanguard_announcements_finished 1
```

### Anomalies Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_anomalies_active | gauge | Active anomalies at the moment | anomaly, anomaly_id, bits, bits_s, duration, packets, pkts_s, prefix
wanguard_anomalies_finished | gauge | Number of finished anomalies |

Example:
```
wanguard_anomalies_active{anomaly="ICMP pkts/s > 1",anomaly_id="1",bits="169576384000",bits_s="9014400",duration="60",packets="320020500",pkts_s="17500",prefix="10.10.10.10/32"} 1
wanguard_anomalies_finished 1
```

### Components Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_component_status | gauge | Status of the component | component_category, component_name

Example:
```
wanguard_component_status{component_category="bgp_connector",component_name="BGP Connector 1"} 1
wanguard_component_status{component_category="filter",component_name="Packet Filter 1"} 1
wanguard_component_status{component_category="sensor",component_name="Flow Sensor 1"} 1
```

### Actions Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_action_status | gauge | Status of the response actions | action_name, action_type, response_branch, response_name

Example:
```
wanguard_action_status{action_name="Action 1",action_type="Send a custom Syslog message",response_branch="When an anomaly is detected",response_name="Response 1"} 1
```

### Sensors Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_sensor_internal_ips | gauge | Total number of internal ip addresses | sensor_id, sensor_name
wanguard_sensor_external_ips | gauge | Total number of external ip addresses | sensor_id, sensor_name
wanguard_sensor_packets_per_second_in | gauge | Incoming packets per second | sensor_id, sensor_name
wanguard_sensor_packets_per_second_out | gauge | Outgoing packets per second | sensor_id, sensor_name
wanguard_sensor_bytes_per_second_in | gauge | Incoming bytes per second | sensor_id, sensor_name
wanguard_sensor_bytes_per_second_out | gauge | Outgoing bytes per second | sensor_id, sensor_name
wanguard_sensor_dropped_in | gauge | Total number of dropped packets in | sensor_id, sensor_name
wanguard_sensor_dropped_out | gauge | Total number of dropped packets out | sensor_id, sensor_name
wanguard_sensor_usage_in | gauge | Interface incoming traffic usage | sensor_id, sensor_name
wanguard_sensor_usage_out | gauge | Interface outgoing traffic usage | sensor_id, sensor_name
wanguard_sensor_load | gauge | Sensors load | sensor_id, sensor_name
wanguard_sensor_cpu | gauge | Sensors CPU usage | sensor_id, sensor_name
wanguard_sensor_ram | gauge | Sensors ram usage | sensor_id, sensor_name

Example:
```
wanguard_sensor_internal_ips{sensor_id="1",sensor_name="Interface 1"} 1
wanguard_sensor_external_ips{sensor_id="1",sensor_name="Interface 1"} 0
wanguard_sensor_packets_per_second_in{sensor_id="1",sensor_name="Interface 1"} 100
wanguard_sensor_bytes_per_second_in{sensor_id="1",sensor_name="Interface 1"} 125
wanguard_sensor_cpu{sensor_id="1",sensor_name="Interface 1"} 0
wanguard_sensor_ram{sensor_id="1",sensor_name="Interface 1"} 128
```

### Traffic Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_traffic_country_packets_per_second_in | gauge | Packets per second in by country | country, country_code
wanguard_traffic_country_packets_per_second_out | gauge | Packets per second out by country | country, country_code
wanguard_traffic_country_bytes_per_second_in | gauge | Bytes per second in by country | country, country_code
wanguard_traffic_country_bytes_per_second_out | gauge | Bytes per second out by country | country, country_code
wanguard_traffic_ip_version_packets_per_second_in | gauge | Packets per second in by IP version | ip_version
wanguard_traffic_ip_version_packets_per_second_out | gauge | Packets per second out by IP version | ip_version
wanguard_traffic_ip_version_bytes_per_second_in | gauge | Bytes per second in by IP version | ip_version
wanguard_traffic_ip_version_bytes_per_second_out | gauge | Bytes per second out by IP version | ip_version
wanguard_traffic_ip_protocol_packets_per_second_in | gauge | Packets per second in by IP protocol | ip_protocol
wanguard_traffic_ip_protocol_packets_per_second_out | gauge | Packets per second out by IP protocol | ip_protocol
wanguard_traffic_ip_protocol_bytes_per_second_in | gauge | Bytes per second in by IP protocol | ip_protocol
wanguard_traffic_ip_protocol_bytes_per_second_out | gauge | Bytes per second out by IP protocol | ip_protocol
wanguard_traffic_talkers_packets_per_second_in | gauge | Packets per second in by IP address | ip_address
wanguard_traffic_talkers_packets_per_second_out | gauge | Packets per second out by IP address | ip_address
wanguard_traffic_talkers_bytes_per_second_in | gauge | Bytes per second in by IP address | ip_address
wanguard_traffic_talkers_bytes_per_second_out | gauge | Bytes per second out by IP address | ip_address

Example:
```
wanguard_traffic_country_packets_per_second_in{country="United States",country_code="US"} 200
wanguard_traffic_country_bytes_per_second_in{country="United States",country_code="US"} 200
wanguard_traffic_ip_version_packets_per_second_in{ip_version="IPv4"} 100
wanguard_traffic_ip_protocol_bytes_per_second_in{ip_protocol="TCP"} 100
wanguard_traffic_talkers_packets_per_second_in{ip_address="10.10.10.10"} 100
```

### Firewall Rules Collector
Metric | Type | Description | Labels
-------|------|-------------|-------
wanguard_firewall_rules_active | gauge | Active firewall rules at the moment | attack_id, bits, bits_s, destination_prefix, from, ip_protocol, max_bits_s, max_pkts_s, pkts, pkts_s, rule_id, source_prefix, until
wanguard_firewall_rules_activated | gauge | Number of activated firewall rules |

Example:
```
wanguard_firewall_rules_active{attack_id="1",bits="0",bits_s="0",destination_prefix="any",from="2024-10-28 06:37:02",ip_protocol="tcp",max_bits_s="0",max_pkts_s="0",pkts="0",pkts_s="0",rule_id="1",source_prefix="any",until=""} 1
wanguard_firewall_rules_activated 1
```
