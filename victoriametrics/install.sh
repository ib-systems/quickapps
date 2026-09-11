#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/victoriametrics

cat > /opt/victoriametrics/docker-compose.yml <<'EOF'
services:

  victoriametrics:
    image: victoriametrics/victoria-metrics:latest
    container_name: victoriametrics
    restart: unless-stopped
    ports:
      - "8428:8428"
    volumes:
      - victoriametrics_data:/storage
    command:
      - "-storageDataPath=/storage"

volumes:
  victoriametrics_data:
EOF

cd /opt/victoriametrics

docker compose up -d
