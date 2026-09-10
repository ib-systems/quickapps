#!/usr/bin/env bash

set -Eeuo pipefail

# ==================================================
# Configuration
# ==================================================

APP_DIR="/opt/suitecrm"
SUITECRM_IMAGE="guerchele/suitecrm:8.10.1"

SUITECRM_ADMIN_USER="root"
SUITECRM_ADMIN_PASSWORD="${SUITECRM_ADMIN_PASSWORD:?SUITECRM_ADMIN_PASSWORD is required}"

SUITECRM_DEMO_DATA="false"
SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS="true"


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
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker


# ==================================================
# 3. Creating directories
# ==================================================

echo "[3/8] Creating directories..."

mkdir -p "$APP_DIR"
cd "$APP_DIR"


# ==================================================
# 4. Generate database credentials
# ==================================================

echo "[4/8] Generating database credentials..."

DB_NAME="suitecrm"
DB_USER="suitecrm"

DB_PASSWORD="$(openssl rand -hex 32)"
DB_ROOT_PASSWORD="$(openssl rand -hex 32)"

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
EOF

chmod 600 "$APP_DIR/.env"


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

cat >> "$APP_DIR/.env" <<EOF
SITE_URL=${SITE_URL}
EOF


# ==================================================
# 6. Create docker-compose.yml
# ==================================================

echo "[6/8] Creating docker-compose.yml..."

cat > "$APP_DIR/docker-compose.yml" <<EOF
services:

  db:
    image: mariadb:10.11
    container_name: suitecrm-db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: \${DB_NAME}
      MYSQL_USER: \${DB_USER}
      MYSQL_PASSWORD: \${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: \${DB_ROOT_PASSWORD}
    volumes:
      - suitecrm_db:/var/lib/mysql
    networks:
      - suitecrm

  suitecrm:
    image: \${SUITECRM_IMAGE}
    container_name: suitecrm
    restart: unless-stopped
    depends_on:
      - db
    environment:
      DB_HOST: db
      DB_NAME: \${DB_NAME}
      DB_USER: \${DB_USER}
      DB_PASSWORD: \${DB_PASSWORD}

      SUITECRM_ADMIN_USER: \${SUITECRM_ADMIN_USER}
      SUITECRM_ADMIN_PASSWORD: \${SUITECRM_ADMIN_PASSWORD}
      SUITECRM_DEMO_DATA: \${SUITECRM_DEMO_DATA}
      SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS: \${SUITECRM_IGNORE_SYSTEM_CHECK_WARNINGS}

      SITE_URL: \${SITE_URL}
    volumes:
      - suitecrm_data:/var/www/html
    networks:
      - suitecrm

  nginx:
    image: nginx:alpine
    container_name: suitecrm-nginx
    restart: unless-stopped
    depends_on:
      - suitecrm
    ports:
      - "80:80"
    volumes:
      - suitecrm_data:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - suitecrm

volumes:
  suitecrm_db:
  suitecrm_data:

networks:
  suitecrm:
EOF


# ==================================================
# 7. Create nginx configuration
# ==================================================

echo "[7/8] Creating nginx configuration..."

cat > "$APP_DIR/nginx.conf" <<'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.php index.html;

    client_max_body_size 100M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass suitecrm:9000;
    }

    location ~ /\. {
        deny all;
    }
}
EOF


# ==================================================
# 8. Start SuiteCRM
# ==================================================

echo "[8/8] Starting SuiteCRM..."

docker compose --env-file "$APP_DIR/.env" up -d

echo
echo "=========================================="
echo "SuiteCRM installation completed"
echo "=========================================="
echo
echo "URL: ${SITE_URL}"
echo "Admin user: ${SUITECRM_ADMIN_USER}"
echo
echo "Containers:"
docker compose ps
