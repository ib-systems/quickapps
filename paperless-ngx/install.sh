#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

: "${PAPERLESS_ADMIN_PASSWORD:?}"

apt-get update
apt-get install -y curl openssl

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

PAPERLESS_DBPASS="$(openssl rand -hex 32)"
PAPERLESS_SECRET_KEY="$(openssl rand -hex 64)"

mkdir -p /opt/paperless-ngx
cd /opt/paperless-ngx

cat > .env <<EOF
PAPERLESS_DBHOST=db
PAPERLESS_DBNAME=paperless_db
PAPERLESS_DBUSER=paperless_user
PAPERLESS_DBPASS=${PAPERLESS_DBPASS}
PAPERLESS_ADMIN_USER=admin
PAPERLESS_ADMIN_PASSWORD=${PAPERLESS_ADMIN_PASSWORD}
PAPERLESS_ADMIN_MAIL=admin@example.com
PAPERLESS_SECRET_KEY=${PAPERLESS_SECRET_KEY}
EOF

chmod 600 .env

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

apt-get install -y docker-compose-plugin

cat > docker-compose.yml <<'EOF'
services:
  paperless-ngx:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    container_name: paperless-ngx
    restart: unless-stopped
    environment:
      PAPERLESS_DBHOST: ${PAPERLESS_DBHOST}
      PAPERLESS_DBNAME: ${PAPERLESS_DBNAME}
      PAPERLESS_DBUSER: ${PAPERLESS_DBUSER}
      PAPERLESS_DBPASS: ${PAPERLESS_DBPASS}
      PAPERLESS_ADMIN_USER: ${PAPERLESS_ADMIN_USER}
      PAPERLESS_ADMIN_PASSWORD: ${PAPERLESS_ADMIN_PASSWORD}
      PAPERLESS_ADMIN_MAIL: ${PAPERLESS_ADMIN_MAIL}
      PAPERLESS_SECRET_KEY: ${PAPERLESS_SECRET_KEY}
      PAPERLESS_REDIS: redis://redis:6379
    ports:
      - "8000:8000"
    volumes:
      - paperless_data:/usr/src/paperless/data
      - paperless_media:/usr/src/paperless/media
    depends_on:
      - db
      - redis
    networks:
      - paperless_network

  db:
    image: postgres:14
    container_name: paperless-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${PAPERLESS_DBUSER}
      POSTGRES_PASSWORD: ${PAPERLESS_DBPASS}
      POSTGRES_DB: ${PAPERLESS_DBNAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - paperless_network

  redis:
    image: redis:alpine
    container_name: paperless-redis
    restart: unless-stopped
    networks:
      - paperless_network

volumes:
  paperless_data:
  paperless_media:
  postgres_data:

networks:
  paperless_network:
    driver: bridge
EOF

docker compose up -d

echo
echo "=========================================="
echo " Paperless-ngx installation completed"
echo "=========================================="
echo
echo "URL      : http://${IP_ADDRESS}:8000"
echo "Username : admin"
echo "Password : ${PAPERLESS_ADMIN_PASSWORD}"
echo
echo "Database credentials: /opt/paperless-ngx/.env"
echo
echo "=========================================="

docker compose ps
