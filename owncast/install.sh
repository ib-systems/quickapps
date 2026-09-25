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

mkdir -p /opt/owncast
cd /opt/owncast

cat <<EOF > docker-compose.yml
services:
  owncast:
    image: gabekangas/owncast:latest
    container_name: owncast
    ports:
      - "8082:8080"
      - "1935:1935"
    volumes:
      - ./config:/app/data/config
      - ./db:/app/data/db
      - ./uploads:/app/data/uploads
      - ./logs:/app/data/logs
    restart: unless-stopped
EOF

docker compose up -d

echo
echo "========================================"
echo "Owncast installation completed"
echo "========================================"
echo
echo "Access URL: http://$IPv4:8082"
echo
