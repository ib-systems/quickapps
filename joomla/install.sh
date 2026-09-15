#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/opt/joomla"

echo "=========================================="
echo " Joomla Quick App Installer"
echo "=========================================="

# ==================================================
# 1. Install dependencies
# ==================================================

echo "[1/7] Installing dependencies..."

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    openssl


# ==================================================
# 2. Install Docker
# ==================================================

echo "[2/9] Installing Docker..."

if ! command -v docker >/dev/null 2>&1; then

    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | sh

fi


# ==================================================
# 3. Create directories
# ==================================================

echo "[3/7] Creating directories..."

mkdir -p "$APP_DIR/joomla"
mkdir -p "$APP_DIR/mysql"
mkdir -p "$APP_DIR/redis"
mkdir -p "$APP_DIR/nginx"


# ==================================================
# 4. Generate database credentials
# ==================================================

echo "[4/7] Generating database credentials..."

DB_NAME="joomla"
DB_USER="joomla"

DB_PASSWORD="$(openssl rand -hex 32)"
DB_ROOT_PASSWORD="$(openssl rand -hex 32)"

cat > "$APP_DIR/.env" <<EOF
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
EOF

chmod 600 "$APP_DIR/.env"

cat > /root/credentials.txt <<EOF
Host: joomla_mysql
Database name: joomla
Database User: joomla
Database Password: ${DB_PASSWORD}
EOF

chmod 600 /root/credentials.txt

# ==================================================
# 5. Create Nginx configuration
# ==================================================

echo "[5/7] Creating Nginx configuration..."

cat > "$APP_DIR/nginx/default.conf" <<'EOF'
server {

    listen 80 default_server;

    server_name _;

    root /var/www/html;

    index index.php index.html;

    client_max_body_size 256M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {

        try_files $uri =404;

        include fastcgi_params;

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        fastcgi_param HTTP_PROXY "";

        fastcgi_pass joomla:9000;
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|webp|woff|woff2|ttf)$ {

        expires 30d;

        access_log off;
    }

    location ~ /\.(?!well-known) {
        deny all;
    }
}
EOF


# ==================================================
# 6. Create Docker Compose
# ==================================================

echo "[6/7] Creating Docker Compose..."

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:

  nginx:
    image: nginx:1.27-alpine

    container_name: joomla_nginx

    restart: unless-stopped

    ports:
      - "80:80"

    volumes:
      - ./joomla:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:
      joomla:
        condition: service_started

    networks:
      - joomla


  joomla:
    image: joomla:6.1.3-php8.4-fpm

    container_name: joomla_php

    restart: unless-stopped

    environment:

      JOOMLA_DB_HOST: mysql:3306

      JOOMLA_DB_USER: ${DB_USER}

      JOOMLA_DB_PASSWORD: ${DB_PASSWORD}

      JOOMLA_DB_NAME: ${DB_NAME}

    volumes:
      - ./joomla:/var/www/html

    depends_on:
      mysql:
        condition: service_healthy

    networks:
      - joomla


  mysql:
    image: mariadb:11.8

    container_name: joomla_mysql

    restart: unless-stopped

    environment:

      MYSQL_DATABASE: ${DB_NAME}

      MYSQL_USER: ${DB_USER}

      MYSQL_PASSWORD: ${DB_PASSWORD}

      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}

    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci

    volumes:
      - ./mysql:/var/lib/mysql

    healthcheck:

      test:
        - CMD
        - healthcheck.sh
        - --connect
        - --innodb_initialized

      interval: 10s

      timeout: 5s

      retries: 15

    networks:
      - joomla


  redis:
    image: redis:7-alpine

    container_name: joomla_redis

    restart: unless-stopped

    command:
      - redis-server
      - --appendonly
      - "yes"

    volumes:
      - ./redis:/data

    networks:
      - joomla


networks:

  joomla:
    driver: bridge
EOF


# ==================================================
# 7. Start Joomla
# ==================================================

echo "[7/7] Starting Joomla..."

cd "$APP_DIR"

docker compose pull

docker compose up -d


# ==================================================
# Wait for MariaDB
# ==================================================

echo "Waiting for MariaDB..."

for i in $(seq 1 60); do

    if docker exec joomla_mysql \
        healthcheck.sh \
        --connect \
        --innodb_initialized \
        >/dev/null 2>&1
    then
        echo "MariaDB is ready."
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "ERROR: MariaDB did not become ready."
        docker compose logs mysql
        exit 1
    fi

    sleep 2

done


# ==================================================
# Wait for Joomla files
# ==================================================

echo "Waiting for Joomla..."

for i in $(seq 1 60); do

    if [ -f "$APP_DIR/joomla/index.php" ]; then
        echo "Joomla files are ready."
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "ERROR: Joomla files were not initialized."
        docker compose logs joomla
        exit 1
    fi

    sleep 2

done


# ==================================================
# Get VPS IP
# ==================================================

SERVER_IP="$(hostname -I | awk '{print $1}')"


# ==================================================
# Save installation status
# ==================================================

cat > "$APP_DIR/install-status" <<EOF
status=ready
application=joomla
url=http://${SERVER_IP}/
administrator_url=http://${SERVER_IP}/administrator/
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

chmod 600 "$APP_DIR/install-status"


# ==================================================
# Final output
# ==================================================

echo
echo "=========================================="
echo " Joomla is ready!"
echo "=========================================="
echo
echo "Installation:"
echo "http://${SERVER_IP}/"
echo
echo "Administrator:"
echo "http://${SERVER_IP}/administrator/"
echo
echo "Database credentials:"
echo "stored in ${APP_DIR}/.env"
echo
echo "Complete the Joomla installation"
echo "from your browser."
echo
echo "=========================================="

docker compose ps
