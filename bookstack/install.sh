#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/bookstack
cd /opt/bookstack

APP_KEY="base64:$(openssl rand -base64 32)"
DB_PASSWORD=$(openssl rand -hex 24)
DB_ROOT_PASSWORD=$(openssl rand -hex 24)

TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone)
SERVER_IP=$(hostname -I | awk '{print $1}')

cat > .env <<EOF
PUID=1000
PGID=1000
TZ=${TZ}

APP_URL=http://${SERVER_IP}:8080
APP_KEY=${APP_KEY}

DB_HOST=bookstack_db
DB_PORT=3306
DB_USERNAME=bookstack
DB_PASSWORD=${DB_PASSWORD}
DB_DATABASE=bookstack

MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
MYSQL_DATABASE=bookstack
MYSQL_USER=bookstack
MYSQL_PASSWORD=${DB_PASSWORD}
EOF

cat > docker-compose.yml <<'EOF'
services:

  bookstack:
    image: lscr.io/linuxserver/bookstack:latest
    container_name: bookstack
    restart: unless-stopped
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - APP_URL=${APP_URL}
      - APP_KEY=${APP_KEY}
      - DB_HOST=${DB_HOST}
      - DB_PORT=${DB_PORT}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_DATABASE=${DB_DATABASE}
    ports:
      - "8080:80"
    volumes:
      - bookstack_config:/config
    depends_on:
      - bookstack_db

  bookstack_db:
    image: lscr.io/linuxserver/mariadb:latest
    container_name: bookstack_db
    restart: unless-stopped
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    volumes:
      - bookstack_db_config:/config

volumes:
  bookstack_config:
  bookstack_db_config:
EOF

docker compose pull
docker compose up -d
