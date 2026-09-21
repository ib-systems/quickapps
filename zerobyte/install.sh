#!/bin/bash

set -e

# Configuration
ZEROBYTE_DIR="/opt/zerobyte"
IP_ADDRESS="$(hostname -I | awk '{print $1}')"
APP_SECRET="$(openssl rand -hex 32)"

# Install required packages
apt-get update
apt-get install -y curl openssl ca-certificates

# Install Docker
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

# Install Zerobyte
mkdir -p "$ZEROBYTE_DIR"
cd "$ZEROBYTE_DIR"

# Create Docker Compose configuration
cat > compose.yaml <<EOF
services:

  zerobyte:
    image: ghcr.io/nicotsx/zerobyte:v0.42
    container_name: zerobyte
    restart: unless-stopped

    cap_add:
      - SYS_ADMIN

    devices:
      - /dev/fuse:/dev/fuse

    ports:
      - "4096:4096"

    environment:
      BASE_URL: http://${IP_ADDRESS}:4096
      APP_SECRET: ${APP_SECRET}

    volumes:
      - /var/lib/zerobyte:/var/lib/zerobyte
EOF

# Start Zerobyte
docker compose pull
docker compose up -d

echo ""
echo "=========================================="
echo " Zerobyte installation completed"
echo "=========================================="
echo ""
echo "URL : http://${IP_ADDRESS}:4096"
echo ""
echo "Directory : ${ZEROBYTE_DIR}"
echo ""
echo "=========================================="
