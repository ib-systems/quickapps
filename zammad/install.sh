#!/bin/bash
set -e

apt-mark hold qemu-guest-agent
apt-get update
apt-get install -y curl git

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

apt-mark unhold qemu-guest-agent

ZAMMAD_DIR="/opt/zammad"

mkdir -p "$ZAMMAD_DIR"
cd "$ZAMMAD_DIR"

git clone https://github.com/zammad/zammad-docker-compose.git .

docker compose -p zammad up -d

echo
echo "=========================================="
echo " Zammad installation completed"
echo "=========================================="
echo
echo "URL : http://$(hostname -I | awk '{print $1}')"
echo
echo "=========================================="

docker compose -p zammad ps
