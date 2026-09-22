#!/bin/bash

set -e

apt-get update
apt-get install -y curl

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

mkdir -p /root/.memos

docker run -d \
    --name memos \
    --restart unless-stopped \
    -p 5230:5230 \
    -v /root/.memos:/var/opt/memos \
    neosmemo/memos:stable

echo
echo "=========================================="
echo " Memos installation completed"
echo "=========================================="
echo
echo "URL : http://${IP_ADDRESS}:5230"
echo
echo "=========================================="

docker ps
