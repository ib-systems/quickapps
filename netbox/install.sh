#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates git

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/netbox
cd /opt/netbox

git clone -b release https://github.com/netbox-community/netbox-docker.git .

cat > docker-compose.override.yml <<EOF
services:
  netbox:
    ports:
      - "8000:8080"
    environment:
      SKIP_SUPERUSER: "false"
      SUPERUSER_NAME: "admin"
      SUPERUSER_EMAIL: "admin@localhost"
      SUPERUSER_PASSWORD: "${NETBOX_ADMIN_PASSWORD}"
EOF

docker compose pull
docker compose up -d
