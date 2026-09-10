#!/bin/bash

set -e

apt-get update
apt-get install -y curl wget ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi


systemctl enable --now docker

mkdir -p /opt/seafile
cd /opt/seafile

wget -q -O .env \
    https://manual.seafile.com/13.0/repo/docker/ce/env

wget -q \
    https://manual.seafile.com/13.0/repo/docker/ce/seafile-server.yml

wget -q \
    https://manual.seafile.com/13.0/repo/docker/seadoc.yml

DB_ROOT_PASSWORD=$(openssl rand -hex 24)
DB_PASSWORD=$(openssl rand -hex 24)
JWT_PRIVATE_KEY=$(openssl rand -hex 32)

cat >> .env <<EOF

COMPOSE_FILE='seafile-server.yml,seadoc.yml'

SEAFILE_IMAGE=seafileltd/seafile-mc:13.0-latest
SEAFILE_DB_IMAGE=mariadb:10.11
SEAFILE_REDIS_IMAGE=redis
SEADOC_IMAGE=seafileltd/sdoc-server:2.0-latest

SEAFILE_VOLUME=/opt/seafile-data
SEAFILE_MYSQL_VOLUME=/opt/seafile-mysql/db

INIT_SEAFILE_MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
SEAFILE_MYSQL_DB_HOST=db
SEAFILE_MYSQL_DB_PORT=3306
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=${DB_PASSWORD}

SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

CACHE_PROVIDER=redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=$(openssl rand -hex 24)

SEAFILE_SERVER_HOSTNAME=$(hostname -I | awk '{print $1}')
SEAFILE_SERVER_PROTOCOL=http

TIME_ZONE=Etc/UTC

JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY}

INIT_SEAFILE_ADMIN_EMAIL=admin
INIT_SEAFILE_ADMIN_PASSWORD=${SEAFILE_ADMIN_PASSWORD}

ENABLE_SEADOC=true
EOF

sed -i 's/^    # ports:$/    ports:/' seafile-server.yml
sed -i 's/^    #   - "80:80"$/      - "80:80"/' seafile-server.yml

docker compose up -d
