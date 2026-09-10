#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/opt/suitecrm"

SUITECRM_IMAGE="guerchele/suitecrm:8.10.1"

# ==================================================
# SuiteCRM administrator
# Password MUST be supplied by cloud-init
# ==================================================

SUITECRM_ADMIN_USER="root"

SUITECRM_ADMIN_PASSWORD="${SUITECRM_ADMIN_PASSWORD:?SUITECRM_ADMIN_PASSWORD is required}"

SUITECRM_DEMO_DATA="false"

SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS="true"

echo "=========================================="
echo " SuiteCRM Quick App Installer"
echo "=========================================="


# ==================================================
# 1. Install dependencies
# ==================================================

echo "[1/8] Installing dependencies..."

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    openssl


# ==================================================
# 2. Install Docker
# ==================================================

echo "[2/8] Installing Docker..."

if ! command -v docker >/dev/null 2>&1; then

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

fi

systemctl enable docker
systemctl start docker


# ==================================================
# 3. Create directories
# ==================================================

echo "[3/8] Creating directories..."

mkdir -p "$APP_DIR/suitecrm"
mkdir -p "$APP_DIR/mysql"
mkdir -p "$APP_DIR/nginx"


# ==================================================
# 4. Generate database credentials
# ==================================================

echo "[4/8] Generating database credentials..."

DB_NAME="suitecrm"
DB_USER="suitecrm"

DB_PASSWORD="$(openssl rand -hex 32)"
DB_ROOT_PASSWORD="$(openssl rand -hex 32)"


# ==================================================
# 5. Get VPS IP
# ==================================================

echo "[5/8] Detecting VPS IP..."

SERVER_IP="$(hostname -I | awk '{print $1}')"

if [ -z "$SERVER_IP" ]; then
    echo "ERROR: Could not determine VPS IP."
    exit 1
fi

SITE_URL="http://${SERVER_IP}"


# ==================================================
# Create .env
# ==================================================

cat > "$APP_DIR/.env" <<EOF
SUITECRM_IMAGE=${SUITECRM_IMAGE}

DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}

SUITECRM_ADMIN_USER=${SUITECRM_ADMIN_USER}
SUITECRM_ADMIN_PASSWORD=${SUITECRM_ADMIN_PASSWORD}
SUITECRM_DEMO_DATA=${SUITECRM_DEMO_DATA}
SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS=${SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS}

SITE_URL=${SITE_URL}
EOF

chmod 600 "$APP_DIR/.env"


# ==================================================
# 6. Create Nginx configuration
# ==================================================

echo "[6/8] Creating Nginx configuration..."

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
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;

    location / {

        proxy_pass http://suitecrm_app:80;

    }

}
EOF


# ==================================================
# 7. Create Docker Compose
# ==================================================

echo "[7/8] Creating Docker Compose..."

cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:

  # ==================================================
  # Nginx
  # ==================================================

  nginx:

    image: nginx:1.31.5

    container_name: suitecrm_nginx

    restart: unless-stopped

    ports:

      - "80:80"

    volumes:

      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:

      - suitecrm

    networks:

      - suitecrm


  # ==================================================
  # SuiteCRM
  # ==================================================

  suitecrm:

    image: ${SUITECRM_IMAGE}

    container_name: suitecrm_app

    restart: unless-stopped

    environment:

      DB_HOST: mysql

      DB_PORT: 3306

      DB_NAME: ${DB_NAME}

      DB_USER: ${DB_USER}

      DB_PASSWORD: ${DB_PASSWORD}

      SITE_URL: ${SITE_URL}

      SUITECRM_ADMIN_USER: ${SUITECRM_ADMIN_USER}

      SUITECRM_ADMIN_PASSWORD: ${SUITECRM_ADMIN_PASSWORD}

      SUITECRM_DEMO_DATA: ${SUITECRM_DEMO_DATA}

      SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS: ${SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS}

    volumes:

      - ./suitecrm:/var/lib/suitecrm

    depends_on:

      - mysql

    networks:

      - suitecrm


  # ==================================================
  # MariaDB
  # ==================================================

  mysql:

    image: mariadb:10.11

    container_name: suitecrm_mysql

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

    networks:

      - suitecrm


# ==================================================
# Network
# ==================================================

networks:

  suitecrm:

    driver: bridge

EOF
# ==================================================
# 8. Pull and start containers
# ==================================================

echo "[8/8] Starting SuiteCRM..."

cd "$APP_DIR"

docker compose pull

docker compose up -d


# ==================================================
# Wait for MariaDB
# ==================================================

echo
echo "Waiting for MariaDB..."

for i in $(seq 1 60); do

    if docker exec suitecrm_mysql \
        mariadb-admin \
        ping \
        -h 127.0.0.1 \
        -u root \
        -p"$DB_ROOT_PASSWORD" \
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
# Wait for SuiteCRM
# ==================================================

echo "Waiting for SuiteCRM..."

for i in $(seq 1 90); do

    if curl \
        -fsS \
        --max-time 5 \
        "http://${SERVER_IP}/" \
        >/dev/null 2>&1
    then

        echo "SuiteCRM is responding."

        break

    fi

    if [ "$i" -eq 90 ]; then

        echo "ERROR: SuiteCRM did not become ready."

        docker compose logs suitecrm

        exit 1

    fi

    sleep 2

done


# ==================================================
# Save installation status
# ==================================================

cat > "$APP_DIR/install-status" <<EOF
status=ready
application=suitecrm
version=8.10.1
url=${SITE_URL}/
admin_username=${SUITECRM_ADMIN_USER}
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

chmod 600 "$APP_DIR/install-status"


# ==================================================
# Final output
# ==================================================

echo
echo "=========================================="
echo " SuiteCRM is ready!"
echo "=========================================="
echo
echo "URL:"
echo
echo "${SITE_URL}/"
echo
echo "Administrator:"
echo
echo "Username: ${SUITECRM_ADMIN_USER}"
echo "Password: root password"
echo
echo "Database credentials:"
echo
echo "${APP_DIR}/.env"
echo
echo "=========================================="
echo

docker compose ps
