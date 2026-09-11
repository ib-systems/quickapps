#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi


systemctl enable --now docker

mkdir -p /opt/joplin
cd /opt/joplin

POSTGRES_PASSWORD=$(openssl rand -hex 24)

APP_BASE_URL="http://$(hostname -I | awk '{print $1}'):22300"

cat > .env <<EOF
APP_BASE_URL=${APP_BASE_URL}
APP_PORT=22300

DB_CLIENT=pg
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DATABASE=joplin
POSTGRES_USER=joplin
POSTGRES_PORT=5432
POSTGRES_HOST=db
EOF

cat > docker-compose.yml <<'EOF'
services:

  db:
    image: postgres:16
    container_name: joplin_db
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DATABASE}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - joplin

  app:
    image: joplin/server:latest
    container_name: joplin
    restart: unless-stopped
    depends_on:
      - db
    ports:
      - "22300:22300"
    environment:
      APP_PORT: ${APP_PORT}
      APP_BASE_URL: ${APP_BASE_URL}
      DB_CLIENT: ${DB_CLIENT}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DATABASE: ${POSTGRES_DATABASE}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PORT: ${POSTGRES_PORT}
      POSTGRES_HOST: ${POSTGRES_HOST}
    networks:
      - joplin

networks:
  joplin:

volumes:
  postgres_data:
EOF

docker compose pull
docker compose up -d
