#!/bin/bash
set -e

LARANODE_DIR="/opt/laranode"
LARANODE_EMAIL="admin@example.com"

# Docker
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

# Dependencies
apt-get update
apt-get install -y git

# Laranode
if [ ! -d "${LARANODE_DIR}" ]; then
    git clone https://github.com/crivion/laranode.git "${LARANODE_DIR}"
fi

cd "${LARANODE_DIR}"

# Build and start Laranode
docker compose up -d --build

# Wait for Laranode to become healthy
echo "Waiting for Laranode to become healthy..."

until [ "$(docker inspect -f '{{.State.Health.Status}}' laranode 2>/dev/null)" = "healthy" ]; do
    sleep 5
done

echo "Laranode is healthy."

# Create admin
printf 'admin\n%s\n%s\n' \
    "${LARANODE_EMAIL}" \
    "${LARANODE_PASSWORD}" |
docker compose exec -T laranode \
    laranode-artisan laranode:create-admin

echo
echo "======================================"
echo "Laranode installation completed"
echo "======================================"
echo
echo "URL: http://$(hostname -I | awk '{print $1}')/"
echo "Email: ${LARANODE_EMAIL}"
echo
docker compose ps
