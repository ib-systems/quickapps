#!/usr/bin/env bash

set -e

APP_DIR="/opt/wordpress"

echo "=========================================="
echo " WordPress Docker Installer"
echo "=========================================="

# --------------------------------------------------
# Install Docker
# --------------------------------------------------

echo "[1/5] Installing Docker..."

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    openssl

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker


# --------------------------------------------------
# Create directories
# --------------------------------------------------

echo "[2/5] Creating directories..."

mkdir -p "$APP_DIR/wordpress"
mkdir -p "$APP_DIR/mysql"
mkdir -p "$APP_DIR/redis"
mkdir -p "$APP_DIR/nginx"


# --------------------------------------------------
# Generate database passwords
# --------------------------------------------------

echo "[3/5] Generating credentials..."

DB_PASSWORD="$(openssl rand -hex 32)"
DB_ROOT_PASSWORD="$(openssl rand -hex 32)"

cat > "$APP_DIR/.env" <<EOF
DB_NAME=wordpress
DB_USER=wordpress
DB_PASSWORD=$DB_PASSWORD
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
EOF

chmod 600 "$APP_DIR/.env"


# --------------------------------------------------
# Nginx
# --------------------------------------------------

echo "[4/5] Creating Nginx configuration..."

cat > "$APP_DIR/nginx/default.conf" <<'EOF'
server {

    listen 80 default_server;

    server_name _;

    root /var/www/html;

    index index.php index.html;

    client_max_body_size 256M;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {

        try_files $uri =404;

        include fastcgi_params;

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        fastcgi_pass wordpress:9000;
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|webp|woff|woff2)$ {

        expires 30d;

        access_log off;
    }
}
EOF


# --------------------------------------------------
# Docker Compose
# --------------------------------------------------

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:

  nginx:
    image: nginx:1.27-alpine
    container_name: wordpress_nginx
    restart: unless-stopped

    ports:
      - "80:80"

    volumes:
      - ./wordpress:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:
      - wordpress

    networks:
      - wordpress


  wordpress:
    image: wordpress:6.8-php8.3-fpm
    container_name: wordpress_php
    restart: unless-stopped

    environment:
      WORDPRESS_DB_HOST: mysql:3306
      WORDPRESS_DB_NAME: ${DB_NAME}
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}

    volumes:
      - ./wordpress:/var/www/html

    depends_on:
      mysql:
        condition: service_healthy

    networks:
      - wordpress


  mysql:
    image: mariadb:11.8
    container_name: wordpress_mysql
    restart: unless-stopped

    environment:
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}

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
      retries: 10

    networks:
      - wordpress


  redis:
    image: redis:7-alpine
    container_name: wordpress_redis
    restart: unless-stopped

    command:
      - redis-server
      - --appendonly
      - "yes"

    volumes:
      - ./redis:/data

    networks:
      - wordpress


networks:

  wordpress:
    driver: bridge
EOF


# --------------------------------------------------
# Start
# --------------------------------------------------

echo "[5/5] Starting WordPress..."

cd "$APP_DIR"

docker compose pull

docker compose up -d

echo
echo "=========================================="
echo " WordPress installed successfully"
echo "=========================================="
echo

docker compose ps

echo
echo "WordPress:"
echo "http://$(hostname -I | awk '{print $1}')"
echo
