#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/syncthing
cd /opt/syncthing

cat > docker-compose.yml <<'EOF'
services:

  syncthing:
    image: syncthing/syncthing:latest
    container_name: syncthing
    hostname: syncthing
    restart: unless-stopped
    ports:
      - "8384:8384"
      - "22000:22000/tcp"
      - "22000:22000/udp"
      - "21027:21027/udp"
    volumes:
      - syncthing_data:/var/syncthing

volumes:
  syncthing_data:
EOF

docker compose up -d
