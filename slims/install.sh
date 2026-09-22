#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl ca-certificates unzip openssl

MYSQL_PASSWORD="$(openssl rand -base64 32)"
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 32)"

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

apt-get install -y docker-compose-plugin

mkdir -p /opt/slims
cd /opt/slims

curl -LO https://github.com/slims/slims9_bulian/archive/refs/tags/v9.7.2.zip

unzip v9.7.2.zip
mv slims9_bulian-9.7.2 slims9
rm v9.7.2.zip

cat > .env <<EOF
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
EOF

chmod 600 .env

cat > docker-compose.yml <<'EOF'
services:
  slims-db:
    image: mariadb:10.11
    container_name: slims-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: slims9
      MYSQL_USER: slims_user
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - slims-db-data:/var/lib/mysql
    networks:
      - slims-net

  slims-web:
    build: .
    container_name: slims-web
    restart: unless-stopped
    depends_on:
      - slims-db
    volumes:
      - ./slims9:/var/www/html
    ports:
      - "8080:80"
    networks:
      - slims-net

volumes:
  slims-db-data:

networks:
  slims-net:
EOF

cat > Dockerfile <<'EOF'
FROM php:8.3-apache

RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    gettext \
    unzip \
    yaz \
    libyaz-dev \
    gcc \
    make \
    autoconf \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install mysqli pdo pdo_mysql mbstring gd gettext zip \
    && pecl install yaz \
    && docker-php-ext-enable yaz \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    /var/www/html/config \
    /var/www/html/files \
    /var/www/html/images \
    /var/www/html/repository \
    && chown -R www-data:www-data \
    /var/www/html/config \
    /var/www/html/files \
    /var/www/html/images \
    /var/www/html/repository \
    && chmod -R 775 \
    /var/www/html/config \
    /var/www/html/files \
    /var/www/html/images \
    /var/www/html/repository

CMD ["apache2-foreground"]
EOF

docker compose up -d --build

docker exec -u root slims-web \
    chown -R 33:33 \
    /var/www/html/config \
    /var/www/html/files \
    /var/www/html/images \
    /var/www/html/repository

docker exec -u root slims-web \
    chmod -R 775 \
    /var/www/html/config \
    /var/www/html/files \
    /var/www/html/images \
    /var/www/html/repository

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

echo
echo "=========================================="
echo " SLiMS installation completed"
echo "=========================================="
echo
echo "URL : http://${IP_ADDRESS}:8080"
echo
echo "Database credentials: /opt/slims/.env"
echo
echo "=========================================="

docker compose ps
