#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

set -e

IPv4=$(hostname -I | awk '{print $1}')

apt-get update
apt-get install -y curl

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

docker run \
    -d \
    --name baserow \
    -e BASEROW_PUBLIC_URL="http://$IPv4" \
    -v baserow_data:/baserow/data \
    -p 80:80 \
    --restart unless-stopped \
    baserow/baserow:2.0.1

sleep 180

echo
echo "========================================"
echo "Baserow installation completed"
echo "========================================"
echo
echo "Access URL: http://$IPv4"
echo
