#!/bin/bash

set -e

apt-get update
apt-get install -y curl wget ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

apt-get install -y docker-compose-plugin
systemctl enable --now docker

mkdir -p /opt/immich
cd /opt/immich

wget -q -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget -q -O .env https://github.com/immich-app/immich/releases/latest/download/example.env

TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone)

sed -i 's|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=./library|' .env
sed -i 's|^DB_DATA_LOCATION=.*|DB_DATA_LOCATION=./postgres|' .env
sed -i 's|^IMMICH_VERSION=.*|IMMICH_VERSION=v3|' .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -hex 24)|" .env
sed -i "s|^# TZ=.*|TZ=${TZ}|" .env

docker compose up -d
