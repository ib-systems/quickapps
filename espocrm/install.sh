#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/opt/espocrm"

# ==================================================
# EspoCRM image
# ==================================================

ESPOCRM_IMAGE="espocrm/espocrm:latest"


# ==================================================
# Required variables
# ==================================================

# IMPORTANT:
# EspoCRM Docker image expects the administrator
# username to be "admin".
ESPOCRM_ADMIN_USERNAME="admin"

ESPOCRM_ADMIN_PASSWORD="${ESPOCRM_ADMIN_PASSWORD:?ESPOCRM_ADMIN_PASSWORD is required}"


# ==================================================
# Start
# ==================================================

echo "=========================================="
echo " EspoCRM Quick App Installer"
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

if ! command -v docker >/dev/null 2>&1; then

    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | sh

fi


# ==================================================
# 3. Create directories
# ==================================================

echo "[3/9] Creating directories..."

mkdir -p "$APP_DIR/nginx"


# ==================================================
# 4. Generate database credentials
# ==================================================

echo "[4/9] Generating database credentials..."

DB_NAME="espocrm"
DB_USER="espocrm"

DB_PASSWORD="$(openssl rand -hex 32)"
DB_ROOT_PASSWORD="$(openssl rand -hex 32)"


# ==================================================
# 5. Detect VPS IP
# ==================================================

echo "[5/9] Detecting VPS IP..."

SERVER_IP="$(hostname -I | awk '{print $1}')"

if [ -z "$SERVER_IP" ]; then
    echo "ERROR: Could not determine VPS IP."
    exit 1
fi

SITE_URL="http://${SERVER_IP}"
WEBSOCKET_URL="ws://${SERVER_IP}/websocket"


# ==================================================
# Create .env
# ==================================================

cat > "$APP_DIR/.env" <<EOF
ESPOCRM_IMAGE=${ESPOCRM_IMAGE}

DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}

ESPOCRM_ADMIN_USERNAME=${ESPOCRM_ADMIN_USERNAME}
ESPOCRM_ADMIN_PASSWORD=${ESPOCRM_ADMIN_PASSWORD}

ESPOCRM_SITE_URL=${SITE_URL}
ESPOCRM_WEBSOCKET_URL=${WEBSOCKET_URL}
EOF

chmod 600 "$APP_DIR/.env"


# ==================================================
# 6. Create Nginx configuration
# ==================================================

echo "[6/9] Creating Nginx configuration..."

cat > "$APP_DIR/nginx/default.conf" <<'EOF'
upstream espocrm {
    server espocrm:80;
}

upstream espocrm_websocket {
    server espocrm-websocket:8080;
}

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
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;


    location / {

        proxy_pass http://espocrm;

    }


    location /websocket {

        proxy_pass http://espocrm_websocket;

        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;

        proxy_set_header Connection "upgrade";

    }

}
EOF


# ==================================================
# 7. Create Docker Compose
# ==================================================

echo "[7/9] Creating Docker Compose..."

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:

  # ==================================================
  # MariaDB
  # ==================================================

  espocrm-db:

    image: mariadb:11.4

    container_name: espocrm-db

    restart: unless-stopped

    environment:

      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}

      MARIADB_DATABASE: ${DB_NAME}

      MARIADB_USER: ${DB_USER}

      MARIADB_PASSWORD: ${DB_PASSWORD}

    volumes:

      - espocrm-db:/var/lib/mysql

    healthcheck:

      test:
        - CMD
        - healthcheck.sh
        - --connect
        - --innodb_initialized

      interval: 20s

      start_period: 10s

      timeout: 10s

      retries: 10

    networks:

      - espocrm


  # ==================================================
  # EspoCRM
  # ==================================================

  espocrm:

    image: ${ESPOCRM_IMAGE}

    container_name: espocrm

    restart: unless-stopped

    environment:

      ESPOCRM_DATABASE_HOST: espocrm-db

      ESPOCRM_DATABASE_USER: ${DB_USER}

      ESPOCRM_DATABASE_PASSWORD: ${DB_PASSWORD}

      ESPOCRM_DATABASE_NAME: ${DB_NAME}

      ESPOCRM_ADMIN_USERNAME: ${ESPOCRM_ADMIN_USERNAME}

      ESPOCRM_ADMIN_PASSWORD: ${ESPOCRM_ADMIN_PASSWORD}

      ESPOCRM_SITE_URL: ${ESPOCRM_SITE_URL}

    volumes:

      - espocrm-data:/var/www/html/data

      - espocrm-custom:/var/www/html/custom

      - espocrm-custom-client:/var/www/html/client/custom

    depends_on:

      espocrm-db:
        condition: service_healthy

    healthcheck:

      test:
        - CMD
        - bin/command
        - app-check

      start_period: 30s

      interval: 30s

      timeout: 20s

      retries: 5

    networks:

      - espocrm


  # ==================================================
  # EspoCRM Daemon
  # ==================================================

  espocrm-daemon:

    image: ${ESPOCRM_IMAGE}

    container_name: espocrm-daemon

    restart: unless-stopped

    volumes_from:

      - espocrm

    entrypoint:

      - docker-daemon.sh

    depends_on:

      espocrm:
        condition: service_healthy

    networks:

      - espocrm


  # ==================================================
  # EspoCRM WebSocket
  # ==================================================

  espocrm-websocket:

    image: ${ESPOCRM_IMAGE}

    container_name: espocrm-websocket

    restart: unless-stopped

    environment:

      ESPOCRM_CONFIG_USE_WEB_SOCKET: "true"

      ESPOCRM_CONFIG_WEB_SOCKET_URL: ${ESPOCRM_WEBSOCKET_URL}

      ESPOCRM_CONFIG_WEB_SOCKET_ZERO_M_Q_SUBSCRIBER_DSN: "tcp://*:7777"

      ESPOCRM_CONFIG_WEB_SOCKET_ZERO_M_Q_SUBMISSION_DSN: "tcp://espocrm-websocket:7777"

    volumes_from:

      - espocrm

    entrypoint:

      - docker-websocket.sh

    depends_on:

      espocrm:
        condition: service_healthy

    networks:

      - espocrm


  # ==================================================
  # Nginx
  # ==================================================

  nginx:

    image: nginx:1.27-alpine

    container_name: espocrm-nginx

    restart: unless-stopped

    ports:

      - "80:80"

    volumes:

      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:

      espocrm:
        condition: service_healthy

      espocrm-websocket:
        condition: service_started

    networks:

      - espocrm


# ==================================================
# Volumes
# ==================================================

volumes:

  espocrm-db:

  espocrm-data:

  espocrm-custom:

  espocrm-custom-client:


# ==================================================
# Network
# ==================================================

networks:

  espocrm:

    driver: bridge
EOF


# ==================================================
# Validate Docker Compose
# ==================================================

echo "Validating Docker Compose configuration..."

cd "$APP_DIR"

if ! docker compose config >/dev/null; then

    echo
    echo "ERROR: Invalid Docker Compose configuration."
    echo

    docker compose config

    exit 1

fi

echo "Docker Compose configuration is valid."


# ==================================================
# 8. Start containers
# ==================================================

echo "[8/9] Starting EspoCRM..."

docker compose pull

docker compose up -d


# ==================================================
# 9. Wait for EspoCRM
# ==================================================

echo "[9/9] Waiting for EspoCRM..."

for i in $(seq 1 120); do

    if curl \
        -fsS \
        --max-time 5 \
        "http://127.0.0.1/" \
        >/dev/null 2>&1
    then

        echo "EspoCRM is ready."

        break

    fi

    if [ "$i" -eq 120 ]; then

        echo
        echo "ERROR: EspoCRM did not become ready."
        echo

        docker compose ps

        echo

        docker compose logs --tail=100 espocrm

        exit 1

    fi

    sleep 2

done


# ==================================================
# Verify installation
# ==================================================

echo
echo "Checking EspoCRM installation..."

for i in $(seq 1 30); do

    INSTALLED="$(docker exec espocrm bin/command config:get isInstalled 2>/dev/null || true)"

    if [ "$INSTALLED" = "true" ]; then

        echo "EspoCRM installation completed successfully."

        break

    fi

    if [ "$i" -eq 30 ]; then

        echo
        echo "ERROR: EspoCRM installation did not complete."
        echo

        docker compose ps

        echo

        docker compose logs --tail=100 espocrm

        exit 1

    fi

    sleep 2

done


# ==================================================
# Save installation status
# ==================================================

cat > "$APP_DIR/install-status" <<EOF
status=ready
application=espocrm
url=${SITE_URL}/
admin_username=${ESPOCRM_ADMIN_USERNAME}
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

chmod 600 "$APP_DIR/install-status"


# ==================================================
# Final output
# ==================================================

echo
echo "=========================================="
echo " EspoCRM is ready!"
echo "=========================================="
echo
echo "URL:"
echo
echo "${SITE_URL}/"
echo
echo "Administrator:"
echo
echo "Username: ${ESPOCRM_ADMIN_USERNAME}"
echo "Password: supplied from cloud-init"
echo
echo "Database credentials:"
echo
echo "${APP_DIR}/.env"
echo
echo "=========================================="
echo

docker compose ps
