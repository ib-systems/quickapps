#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl ca-certificates openssl

MYSQL_PASSWORD="$(openssl rand -base64 32)"
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 32)"

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

apt-get install -y docker-compose-plugin

mkdir -p /opt/krayin
cd /opt/krayin

cat <<EOF > docker-compose.yml
services:
  mysql:
    image: mysql:8.0
    container_name: krayin-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: krayin
      MYSQL_USER: krayin
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - krayin-mysql-data:/var/lib/mysql

  krayin:
    image: webkul/krayin:2.0.1
    container_name: krayin-crm
    restart: unless-stopped
    environment:
      DB_CONNECTION: mysql
      DB_HOST: mysql
      DB_PORT: 3306
      DB_DATABASE: krayin
      DB_USERNAME: krayin
      DB_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - krayin-storage:/var/www/html/storage
    ports:
      - "8082:80"
    depends_on:
      - mysql

volumes:
  krayin-mysql-data:
  krayin-storage:
EOF

docker compose up -d

sleep 30

docker exec krayin-crm php /var/www/html/laravel-crm/artisan migrate
docker exec krayin-crm php /var/www/html/laravel-crm/artisan db:seed
docker exec krayin-crm sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' /var/www/html/laravel-crm/.env

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

echo
echo "=========================================="
echo " Krayin installation completed"
echo "=========================================="
echo
echo "URL      : http://${IP_ADDRESS}:8082/admin/login"
echo "Email    : admin@example.com"
echo "Password : admin123"
echo
echo "=========================================="

docker compose ps
