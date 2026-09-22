#!/bin/bash

set -e

apt-get update
apt-get install -y curl

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

curl -LO https://github.com/knadh/listmonk/raw/master/docker-compose.yml

docker compose up -d

echo
echo "=========================================="
echo " Listmonk installation completed"
echo "=========================================="
echo
echo "URL : http://${IP_ADDRESS}:9000"
echo
echo "=========================================="
