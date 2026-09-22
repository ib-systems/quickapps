#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl

timezone=$(cat /etc/timezone)

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /root/homebox
chown -R 65532:65532 /root/homebox

docker run -d \
    --name homebox \
    --restart unless-stopped \
    -p 3100:7745 \
    -e TZ="$timezone" \
    -e HBOX_OPTIONS_ALLOW_ANALYTICS=false \
    -v /root/homebox:/data \
    ghcr.io/sysadminsmedia/homebox:latest

echo
echo "======================================"
echo "Homebox installation completed"
echo "======================================"
echo
echo "URL: http://$(hostname -I | awk '{print $1}'):3100/"
echo
docker ps
