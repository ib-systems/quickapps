#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

SEMAPHORE_DB_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)"

docker volume create semaphore_data
docker volume create semaphore_postgres

docker network create semaphore-net 2>/dev/null || true

docker run -d \
    --name semaphore-postgres \
    --restart unless-stopped \
    --network semaphore-net \
    -v semaphore_postgres:/var/lib/postgresql/data \
    -e POSTGRES_USER=semaphore \
    -e POSTGRES_PASSWORD="$SEMAPHORE_DB_PASSWORD" \
    -e POSTGRES_DB=semaphore \
    postgres:16

docker run -d \
    --name semaphore \
    --restart unless-stopped \
    -p 3000:3000 \
    -v semaphore_data:/etc/semaphore \
    --network semaphore-net \
    -e SEMAPHORE_DB_DIALECT=postgres \
    -e SEMAPHORE_DB_HOST=semaphore-postgres \
    -e SEMAPHORE_DB_PORT=5432 \
    -e SEMAPHORE_DB_USER=semaphore \
    -e SEMAPHORE_DB_PASS="$SEMAPHORE_DB_PASSWORD" \
    -e SEMAPHORE_DB_NAME=semaphore \
    -e SEMAPHORE_ADMIN=admin@example.com \
    -e SEMAPHORE_ADMIN_PASSWORD="$SEMAPHORE_ADMIN_PASSWORD" \
    -e SEMAPHORE_ADMIN_NAME=Admin \
    -e SEMAPHORE_ADMIN_EMAIL=admin@example.com \
    semaphoreui/semaphore:latest
