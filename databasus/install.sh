#!/bin/bash
set -e

DATABASUS_DIR="/opt/databasus"

# Docker
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

# Databasus directory
mkdir -p "${DATABASUS_DIR}/databasus-data"

# Docker Compose
cat > "${DATABASUS_DIR}/docker-compose.yml" <<'EOF'
services:
  databasus:
    container_name: databasus
    image: databasus/databasus:latest
    ports:
      - "4005:4005"
    volumes:
      - ./databasus-data:/databasus-data
    restart: unless-stopped
EOF

chmod 600 "${DATABASUS_DIR}/docker-compose.yml"

cd "${DATABASUS_DIR}"

docker compose pull
docker compose up -d

echo
echo "======================================"
echo "Databasus installation completed"
echo "======================================"
echo
echo "URL: http://$(hostname -I | awk '{print $1}'):4005"
echo
docker compose ps
