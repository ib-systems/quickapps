#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates docker-compose-plugin

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/grafana/prometheus
mkdir -p /opt/grafana/grafana/provisioning/datasources

cat > /opt/grafana/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
          - prometheus:9090

  - job_name: node
    static_configs:
      - targets:
          - node-exporter:9100
EOF

cat > /opt/grafana/grafana/provisioning/datasources/prometheus.yml <<'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

cat > /opt/grafana/docker-compose.yml <<'EOF'
services:

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    pid: host
    volumes:
      - /:/host:ro,rslave
    command:
      - --path.rootfs=/host

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}

volumes:
  prometheus_data:
  grafana_data:
EOF

cat > /opt/grafana/.env <<EOF
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}
EOF

cd /opt/grafana

docker compose up -d
