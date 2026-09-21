#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive
# Install required packages
apt-get update
apt-get install -y curl pwgen ca-certificates

# Configuration
BAGISTO_DIR="/opt/bagisto"
IP_ADDRESS="$(hostname -I | awk '{print $1}')"
TIMEZONE="UTC"
DB_PASSWORD="$(pwgen -s 32 1)"
DB_ROOT_PASSWORD="$(pwgen -s 32 1)"


# Install Docker
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

# Install Bagisto
mkdir -p "$BAGISTO_DIR"
cd "$BAGISTO_DIR"

# Create Docker Compose configuration
cat > compose.yaml <<EOF
services:

  bagisto:
    image: webkul/bagisto:2.4.10-nginx-mysql
    container_name: bagisto
    restart: unless-stopped

    ports:
      - "80:80"

    environment:
      APP_URL: http://${IP_ADDRESS}
      APP_TIMEZONE: ${TIMEZONE}
      APP_LOCALE: en
      APP_CURRENCY: USD
      APP_ADMIN_URL: admin

      DB_CONNECTION: mysql
      DB_HOST: mysql
      DB_PORT: 3306
      DB_DATABASE: bagisto
      DB_USERNAME: bagisto
      DB_PASSWORD: ${DB_PASSWORD}

    volumes:
      - bagisto_storage:/var/www/html/storage
      - bagisto_public:/var/www/html/public/storage

    depends_on:
      - mysql

  mysql:
    image: mysql:8.0
    container_name: bagisto-mysql
    restart: unless-stopped

    environment:
      MYSQL_DATABASE: bagisto
      MYSQL_USER: bagisto
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}

    volumes:
      - bagisto_mysql:/var/lib/mysql

volumes:
  bagisto_storage:
  bagisto_public:
  bagisto_mysql:
EOF

# Pull images
docker compose pull

# Start Bagisto
docker compose up -d

sleep 60 

docker exec bagisto php artisan migrate --force
docker exec bagisto php artisan db:seed --force

echo ""
echo "=========================================="
echo " Bagisto installation completed"
echo "=========================================="
echo ""
echo "Store URL  : http://${IP_ADDRESS}"
echo "Admin URL  : http://${IP_ADDRESS}/admin"
echo "Email      : admin@example.com"
echo "Password   : admin123"
echo ""
echo "Directory  : ${BAGISTO_DIR}"
echo ""
echo "=========================================="
