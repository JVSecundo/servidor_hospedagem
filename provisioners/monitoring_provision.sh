#!/bin/bash
set -e

echo "Iniciando configuração do sistema de monitoramento..."

# Variáveis
PROMETHEUS_VERSION="2.45.0"
NODE_EXPORTER_VERSION="1.6.0"
GRAFANA_VERSION="10.0.3"

# Criar usuários do sistema
useradd --no-create-home --shell /bin/false prometheus
useradd --no-create-home --shell /bin/false node_exporter
useradd --no-create-home --shell /bin/false grafana

# Criar diretórios
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus
mkdir -p /etc/grafana
mkdir -p /var/lib/grafana

# Instalar Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64

cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/
cp -r consoles/ /etc/prometheus
cp -r console_libraries/ /etc/prometheus

# Configurar Prometheus
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'apache'
    static_configs:
      - targets: ['localhost:80']

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['localhost:8080']
EOF

# Configurar serviço do Prometheus
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

# Instalar Node Exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/

# Configurar serviço do Node Exporter
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Instalar Grafana
cd /tmp
wget https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb
dpkg -i grafana_${GRAFANA_VERSION}_amd64.deb

# Configurar datasource do Prometheus no Grafana
cat > /etc/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

# Configurar permissões
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
chown -R grafana:grafana /var/lib/grafana

# Iniciar serviços
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
systemctl enable node_exporter
systemctl start node_exporter
systemctl enable grafana-server
systemctl start grafana-server

# Configurar alertas básicos
cat > /etc/prometheus/alerts.yml << EOF
groups:
- name: basic_alerts
  rules:
  - alert: HighCPULoad
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High CPU load
      description: CPU load is > 80%
      
  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High memory usage
      description: Memory usage is > 80%
      
  - alert: DiskSpaceRunningLow
    expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 20
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: Low disk space
      description: Disk space is < 20%
EOF

echo "Configuração do sistema de monitoramento concluída!"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000 (admin/admin)"