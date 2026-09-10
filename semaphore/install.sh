#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

docker volume create semaphore_data

docker run -d \
    --name semaphore \
    --restart unless-stopped \
    -p 3000:3000 \
    -v semaphore_data:/etc/semaphore \
    -e SEMAPHORE_DB_DIALECT=bolt \
    -e SEMAPHORE_ADMIN=admin \
    -e SEMAPHORE_ADMIN_PASSWORD="$SEMAPHORE_ADMIN_PASSWORD" \
    -e SEMAPHORE_ADMIN_NAME=Admin \
    -e SEMAPHORE_ADMIN_EMAIL=admin@localhost \
    semaphoreui/semaphore:latest
