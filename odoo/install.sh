#!/usr/bin/env bash

set -Eeuo pipefail

APP_DIR="/opt/odoo"

echo "=========================================="
echo " Odoo Quick App Installer"
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

echo "[2/9] Installing Docker..."

if ! command -v docker >/dev/null 2>&1; then

    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | sh

fi

# ==================================================
# 3. Create directories
# ==================================================

echo "[3/8] Creating directories..."

mkdir -p "$APP_DIR/odoo"
mkdir -p "$APP_DIR/postgres"
mkdir -p "$APP_DIR/addons"
mkdir -p "$APP_DIR/nginx"

# IMPORTANT:
# Odoo runs as user "odoo" inside the container.
# The official Odoo image uses UID/GID 101.
#
# The bind-mounted /var/lib/odoo directory is created
# by root on the VPS, therefore Odoo cannot write to it.
#
# Fix ownership before starting the container.

echo "Setting Odoo directory permissions..."

chown -R 101:101 "$APP_DIR/odoo"
chmod 700 "$APP_DIR/odoo"

# PostgreSQL also needs write access to its data directory.
# The official PostgreSQL image uses UID/GID 999.

echo "Setting PostgreSQL directory permissions..."

chown -R 999:999 "$APP_DIR/postgres"
chmod 700 "$APP_DIR/postgres"


# ==================================================
# 4. Generate PostgreSQL credentials
# ==================================================

echo "[4/8] Generating PostgreSQL credentials..."

POSTGRES_DB="postgres"
POSTGRES_USER="odoo"
POSTGRES_PASSWORD="$(openssl rand -hex 32)"

cat > "$APP_DIR/.env" <<EOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF

chmod 600 "$APP_DIR/.env"


# ==================================================
# 5. Create Odoo configuration
# ==================================================

echo "[5/8] Creating Odoo configuration..."

cat > "$APP_DIR/odoo.conf" <<'EOF'
[options]

proxy_mode = True

workers = 2

limit_time_cpu = 600

limit_time_real = 1200

limit_request = 8192
EOF

chmod 644 "$APP_DIR/odoo.conf"


# ==================================================
# 6. Create Nginx configuration
# ==================================================

echo "[6/8] Creating Nginx configuration..."

cat > "$APP_DIR/nginx/default.conf" <<'EOF'
upstream odoo {
    server odoo:8069;
}

upstream odoochat {
    server odoo:8072;
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

        proxy_pass http://odoo;

    }


    location /websocket {

        proxy_pass http://odoochat;

        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;

        proxy_set_header Connection "upgrade";

    }


    location /longpolling {

        proxy_pass http://odoochat;

    }


    location ~* /web/static/ {

        proxy_cache_valid 200 90m;

        proxy_buffering on;

        proxy_pass http://odoo;

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

    image: nginx:1.27-alpine

    container_name: odoo_nginx

    restart: unless-stopped

    ports:

      - "80:80"

    volumes:

      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

    depends_on:

      odoo:
        condition: service_started

    networks:

      - odoo


  # ==================================================
  # Odoo
  # ==================================================

  odoo:

    image: odoo:19.0

    container_name: odoo_app

    restart: unless-stopped

    depends_on:

      postgres:
        condition: service_healthy

    environment:

      HOST: postgres

      PORT: 5432

      USER: ${POSTGRES_USER}

      PASSWORD: ${POSTGRES_PASSWORD}

      # IMPORTANT:
      # Prevent Odoo from trying to create ~/.local
      # in a location where it has no permission.

      HOME: /var/lib/odoo

    volumes:

      - ./odoo:/var/lib/odoo

      - ./addons:/mnt/extra-addons

      - ./odoo.conf:/etc/odoo/odoo.conf:ro

    command:

      - odoo

      - --config=/etc/odoo/odoo.conf

    networks:

      - odoo


  # ==================================================
  # PostgreSQL
  # ==================================================

  postgres:

    image: postgres:17

    container_name: odoo_postgres

    restart: unless-stopped

    environment:

      POSTGRES_DB: ${POSTGRES_DB}

      POSTGRES_USER: ${POSTGRES_USER}

      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

    volumes:

      - ./postgres:/var/lib/postgresql/data

    healthcheck:

      test:
        - CMD-SHELL
        - pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}

      interval: 10s

      timeout: 5s

      retries: 15

    networks:

      - odoo


# ==================================================
# Network
# ==================================================

networks:

  odoo:

    driver: bridge
EOF


# ==================================================
# 8. Fix permissions and start containers
# ==================================================

echo "[8/8] Preparing Odoo storage..."

cd "$APP_DIR"

# Odoo 19 runs as uid 100, gid 101.
# The bind-mounted /var/lib/odoo directory must be writable.
chown -R 100:101 "$APP_DIR/odoo"
chmod -R u+rwX "$APP_DIR/odoo"

# Add-ons must also be readable by Odoo.
chown -R 100:101 "$APP_DIR/addons"
chmod -R u+rwX "$APP_DIR/addons"

echo "Pulling Docker images..."

docker compose pull

echo "Starting Odoo..."

docker compose up -d

# ==================================================
# Wait for PostgreSQL
# ==================================================

echo
echo "Waiting for PostgreSQL..."

for i in $(seq 1 60); do

    if docker exec odoo_postgres \
        pg_isready \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        >/dev/null 2>&1
    then

        echo "PostgreSQL is ready."

        break

    fi


    if [ "$i" -eq 60 ]; then

        echo
        echo "ERROR: PostgreSQL did not become ready."
        echo

        docker compose ps

        echo
        docker compose logs --tail=100 postgres

        exit 1

    fi

    sleep 2

done


# ==================================================
# Verify Odoo container
# ==================================================

echo
echo "Checking Odoo container..."

sleep 5

if ! docker inspect odoo_app \
    --format='{{.State.Running}}' \
    2>/dev/null | grep -q true
then

    echo
    echo "ERROR: Odoo container is not running."
    echo

    docker compose ps

    echo
    docker compose logs --tail=100 odoo

    exit 1

fi


# ==================================================
# Verify Odoo filesystem permissions
# ==================================================

echo
echo "Checking Odoo filesystem permissions..."

if ! docker exec odoo_app \
    sh -c 'test -w /var/lib/odoo'
then

    echo
    echo "ERROR: Odoo cannot write to /var/lib/odoo."
    echo

    docker exec odoo_app \
        sh -c 'id; ls -ld /var/lib/odoo; ls -la /var/lib/odoo | head -20' \
        || true

    echo
    docker compose logs --tail=100 odoo

    exit 1

fi

echo "Odoo filesystem permissions are OK."


# ==================================================
# Wait for Odoo HTTP
# ==================================================

echo
echo "Waiting for Odoo..."

ODOO_READY=0

for i in $(seq 1 90); do

    HTTP_CODE="$(curl \
        -s \
        -o /dev/null \
        -w '%{http_code}' \
        --max-time 5 \
        http://127.0.0.1/web/database/selector \
        || true)"

    if [ "$HTTP_CODE" = "200" ] || \
       [ "$HTTP_CODE" = "303" ] || \
       [ "$HTTP_CODE" = "302" ]
    then

        echo "Odoo is ready."

        ODOO_READY=1

        break

    fi


    # If Odoo returns 500, don't silently wait forever.
    if [ "$HTTP_CODE" = "500" ]; then

        echo
        echo "Odoo is returning HTTP 500."
        echo "Checking Odoo logs..."
        echo

        docker compose logs --tail=50 odoo

    fi


    # Check whether the container is still alive.

    if ! docker inspect odoo_app \
        --format='{{.State.Running}}' \
        2>/dev/null | grep -q true
    then

        echo
        echo "ERROR: Odoo container stopped."
        echo

        docker compose ps

        echo
        docker compose logs --tail=100 odoo

        exit 1

    fi

    sleep 2

done


# ==================================================
# Odoo timeout
# ==================================================

if [ "$ODOO_READY" -ne 1 ]; then

    echo
    echo "ERROR: Odoo did not become ready."
    echo

    docker compose ps

    echo
    echo "================ ODOO LOGS ================"
    docker compose logs --tail=150 odoo

    echo
    echo "================ POSTGRES LOGS ================"
    docker compose logs --tail=50 postgres

    exit 1

fi


# ==================================================
# Get VPS IP
# ==================================================

SERVER_IP="$(hostname -I | awk '{print $1}')"

if [ -z "$SERVER_IP" ]; then

    SERVER_IP="YOUR_SERVER_IP"

fi


# ==================================================
# Save installation status
# ==================================================

cat > "$APP_DIR/install-status" <<EOF
status=ready
application=odoo
url=http://${SERVER_IP}/
database_manager=http://${SERVER_IP}/web/database/selector
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

chmod 600 "$APP_DIR/install-status"


# ==================================================
# Final output
# ==================================================

echo
echo "=========================================="
echo " Odoo is ready!"
echo "=========================================="
echo
echo "Odoo:"
echo
echo "http://${SERVER_IP}/"
echo
echo "Database manager:"
echo
echo "http://${SERVER_IP}/web/database/selector"
echo
echo "PostgreSQL credentials:"
echo
echo "${APP_DIR}/.env"
echo
echo "Odoo configuration:"
echo
echo "${APP_DIR}/odoo.conf"
echo
echo "=========================================="
echo

docker compose ps

