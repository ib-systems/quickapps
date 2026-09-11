#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

apt-get install -y docker-compose-plugin

systemctl enable --now docker

mkdir -p /opt/jellyfin
mkdir -p /opt/jellyfin/media

cd /opt/jellyfin

cat > docker-compose.yml <<'EOF'
services:

  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096/tcp"
      - "7359:7359/udp"
    volumes:
      - jellyfin_config:/config
      - jellyfin_cache:/cache
      - ./media:/media

volumes:
  jellyfin_config:
  jellyfin_cache:
EOF

docker compose up -d
