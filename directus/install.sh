#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

DIRECTUS_DIR="/opt/directus"

DIRECTUS_DB_NAME="directus_db"
DIRECTUS_DB_USER="directus_user"
DIRECTUS_DB_PASSWORD="$(openssl rand -hex 24)"
MYSQL_ROOT_PASSWORD="$(openssl rand -hex 24)"

ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?PASSWORD is required}"

apt-get update -y
apt-get install -y ca-certificates curl openssl

if ! command -v docker >/dev/null 2>&1
then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p "$DIRECTUS_DIR"
cd "$DIRECTUS_DIR"

cat > docker-compose.yml <<EOF
services:

  directus:
    image: directus/directus:latest
    container_name: directus
    restart: unless-stopped
    depends_on:
      directus-db:
        condition: service_healthy
    ports:
      - "8055:8055"
    environment:
      SECRET: "$(openssl rand -hex 32)"
      ADMIN_EMAIL: "$ADMIN_EMAIL"
      ADMIN_PASSWORD: "$ADMIN_PASSWORD"
      DB_CLIENT: "mysql"
      DB_HOST: "directus-db"
      DB_PORT: "3306"
      DB_DATABASE: "$DIRECTUS_DB_NAME"
      DB_USER: "$DIRECTUS_DB_USER"
      DB_PASSWORD: "$DIRECTUS_DB_PASSWORD"
    volumes:
      - directus_data:/directus/uploads

  directus-db:
    image: mysql:8.4
    container_name: directus-db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: "$DIRECTUS_DB_NAME"
      MYSQL_USER: "$DIRECTUS_DB_USER"
      MYSQL_PASSWORD: "$DIRECTUS_DB_PASSWORD"
      MYSQL_ROOT_PASSWORD: "$MYSQL_ROOT_PASSWORD"
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test:
        [
          "CMD",
          "mysqladmin",
          "ping",
          "-h",
          "localhost",
          "-u",
          "root",
          "-p$MYSQL_ROOT_PASSWORD"
        ]
      interval: 10s
      timeout: 5s
      retries: 30

volumes:
  directus_data:
  mysql_data:
EOF

docker compose up -d

sleep 60

echo
echo "Directus installed successfully."
echo "Admin URL: http://$(hostname -I | awk '{print $1}'):8055"
echo "Admin Email: $ADMIN_EMAIL"
