#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/opt/drupal"

echo "=========================================="
echo " Drupal Quick App Installer"
echo "=========================================="

# ==================================================
# 1. Install dependencies
# ==================================================

echo "[1/9] Installing dependencies..."

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    openssl


# ==================================================
# 2. Install Docker
# ==================================================

echo "[2/9] Installing Docker..."


curl -fsSL https://get.docker.com | sh

systemctl enable --now docker


# ==================================================
# 3. Create application directories
# ==================================================

echo "[3/9] Creating directories..."

mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/nginx"
mkdir -p "$APP_DIR/drupal"


# ==================================================
# 4. Generate database credentials
# ==================================================

echo "[4/9] Generating database credentials..."

DB_NAME="drupal"
DB_USER="drupal"

DB_PASSWORD="$(openssl rand -hex 32)"
DB_ROOT_PASSWORD="$(openssl rand -hex 32)"


cat > "$APP_DIR/.env" <<EOF
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
EOF

chmod 600 "$APP_DIR/.env"


# ==================================================
# 5. Detect VPS IP
# ==================================================

echo "[5/9] Detecting VPS IP..."

SERVER_IP="$(hostname -I | awk '{print $1}')"

if [ -z "$SERVER_IP" ]; then
    echo "ERROR: Could not determine VPS IP."
    exit 1
fi


# ==================================================
# 6. Create Dockerfile
# ==================================================

echo "[6/9] Creating Drupal Dockerfile..."

cat > "$APP_DIR/Dockerfile" <<'EOF'
FROM drupal:11-apache

RUN a2enmod rewrite

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libzip-dev \
        libicu-dev \
    && docker-php-ext-install \
        zip \
        intl \
    && rm -rf /var/lib/apt/lists/*
EOF


# ==================================================
# 7. Create Nginx configuration
# ==================================================

echo "[7/9] Creating Nginx configuration..."

cat > "$APP_DIR/nginx/default.conf" <<'EOF'
server {

    listen 80 default_server;

    server_name _;

    client_max_body_size 256M;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    location / {
        proxy_pass http://drupal:80;
    }

}
EOF


# ==================================================
# 8. Create Docker Compose
# ==================================================

echo "[8/9] Creating Docker Compose..."

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:

  mysql:

    image: mariadb:11.8

    container_name: drupal_mysql

    restart: unless-stopped

    environment:

      MARIADB_DATABASE: ${DB_NAME}
      MARIADB_USER: ${DB_USER}
      MARIADB_PASSWORD: ${DB_PASSWORD}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}

    volumes:

      - drupal_mysql:/var/lib/mysql

    healthcheck:

      test:
        - CMD
        - healthcheck.sh
        - --connect
        - --innodb_initialized

      interval: 10s
      timeout: 5s
      retries: 10

    networks:

      - drupal


  redis:

    image: redis:7-alpine

    container_name: drupal_redis

    restart: unless-stopped

    command:
      - redis-server
      - --appendonly
      - "yes"

    volumes:

      - drupal_redis:/data

    networks:

      - drupal


  drupal:

    build:

      context: .

    container_name: drupal_php

    restart: unless-stopped

    depends_on:

      mysql:
        condition: service_healthy

      redis:
        condition: service_started

    environment:

      PHP_MEMORY_LIMIT: 512M

    volumes:

      - drupal_data:/var/www/html

    networks:

      - drupal


  nginx:

    image: nginx:1.27-alpine

    container_name: drupal_nginx

    restart: unless-stopped

    ports:

      - "80:80"

    volumes:

      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:

      - drupal

    networks:

      - drupal


volumes:

  drupal_mysql:

  drupal_redis:

  drupal_data:


networks:

  drupal:

    driver: bridge
EOF


# ==================================================
# 9. Build and start Drupal
# ==================================================

echo "[9/9] Preparing Drupal..."

cd "$APP_DIR"

docker compose build --pull

docker compose up -d


# ==================================================
# Wait for MariaDB
# ==================================================

echo
echo "Waiting for MariaDB..."

MYSQL_READY=false

for i in $(seq 1 120); do

    if docker inspect \
        --format='{{.State.Health.Status}}' \
        drupal_mysql 2>/dev/null \
        | grep -q "healthy"
    then

        MYSQL_READY=true

        echo "MariaDB is ready."

        break

    fi

    sleep 2

done


if [ "$MYSQL_READY" != "true" ]; then

    echo "ERROR: MariaDB did not become ready."

    docker compose logs --tail=100 mysql

    exit 1

fi


# ==================================================
# Wait for Drupal files
# ==================================================

echo
echo "Waiting for Drupal files to initialize..."

DRUPAL_FILES_READY=false

for i in $(seq 1 240); do

    if docker exec drupal_php \
        test -f /var/www/html/index.php \
        >/dev/null 2>&1
    then

        DRUPAL_FILES_READY=true

        echo "Drupal files are initialized."

        break

    fi

    if ! docker inspect \
        --format='{{.State.Running}}' \
        drupal_php 2>/dev/null \
        | grep -q "true"
    then

        echo "ERROR: Drupal container stopped unexpectedly."

        docker compose logs --tail=150 drupal

        exit 1

    fi

    sleep 2

done


if [ "$DRUPAL_FILES_READY" != "true" ]; then

    echo "ERROR: Drupal files were not initialized."

    echo
    echo "Drupal logs:"
    echo

    docker compose logs --tail=150 drupal

    exit 1

fi


# ==================================================
# Wait for HTTP
# ==================================================

echo
echo "Waiting for Drupal HTTP service..."

DRUPAL_HTTP_READY=false

for i in $(seq 1 180); do

    if curl \
        -fsS \
        --max-time 10 \
        http://127.0.0.1/ \
        >/dev/null 2>&1
    then

        DRUPAL_HTTP_READY=true

        echo "Drupal is ready."

        break

    fi

    sleep 2

done


if [ "$DRUPAL_HTTP_READY" != "true" ]; then

    echo "ERROR: Drupal HTTP service did not become ready."

    echo
    echo "Nginx logs:"
    docker compose logs --tail=100 nginx

    echo
    echo "Drupal logs:"
    docker compose logs --tail=150 drupal

    exit 1

fi


# ==================================================
# Save installation status
# ==================================================

cat > "$APP_DIR/install-status" <<EOF
status=ready
application=drupal
url=http://${SERVER_IP}/
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

chmod 600 "$APP_DIR/install-status"


# ==================================================
# Final output
# ==================================================

echo
echo "=========================================="
echo " Drupal is ready!"
echo "=========================================="
echo
echo "Open:"
echo
echo "http://${SERVER_IP}/"
echo
echo "Complete the Drupal installation from your browser."
echo
echo "Database:"
echo
echo "Host: mysql"
echo "Database: ${DB_NAME}"
echo "Username: ${DB_USER}"
echo "Password: stored in ${APP_DIR}/.env"
echo
echo "=========================================="
echo

docker compose ps
