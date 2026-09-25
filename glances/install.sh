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

mkdir -p /opt/glance
cd /opt/glance

curl -sL https://github.com/glanceapp/docker-compose-template/archive/refs/heads/main.tar.gz \
    | tar -xzf - --strip-components 2

docker compose up -d

echo
echo "========================================"
echo "Glance installation completed"
echo "========================================"
echo
echo "Access URL: http://$IPv4:8080"
echo
