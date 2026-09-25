#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

set -e

IPv4=$(hostname -I | awk '{print $1}')

apt-get update
apt-get install -y curl

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/termix
cd /opt/termix

cat <<EOF > docker-compose.yml
services:
  termix:
    image: ghcr.io/lukegus/termix:latest
    container_name: termix
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - termix-data:/app/data
    environment:
      PORT: "8080"

volumes:
  termix-data:
    driver: local
EOF

docker compose up -d

echo
echo "========================================"
echo "Termix installation completed"
echo "========================================"
echo
echo "Access URL: http://$IPv4:8080"
echo
