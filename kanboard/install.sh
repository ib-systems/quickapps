#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi


systemctl enable --now docker

mkdir -p /opt/kanboard
cd /opt/kanboard

cat > docker-compose.yml <<'EOF'
services:

  kanboard:
    image: kanboard/kanboard:latest
    container_name: kanboard
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - kanboard_data:/var/www/app/data
      - kanboard_plugins:/var/www/app/plugins
      - kanboard_ssl:/etc/nginx/ssl

volumes:
  kanboard_data:
  kanboard_plugins:
  kanboard_ssl:
EOF

docker compose pull
docker compose up -d
