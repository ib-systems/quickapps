#!/bin/bash

set -euo pipefail

ADGUARD_DIR="/opt/adguardhome"

apt-get update -y
apt-get install -y ca-certificates curl

if ! command -v docker >/dev/null 2>&1
then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker is already installed."
fi

systemctl enable --now docker

mkdir -p "$ADGUARD_DIR/work"
mkdir -p "$ADGUARD_DIR/conf"

# Disable systemd-resolved because AdGuard Home needs port 53
if systemctl is-active --quiet systemd-resolved
then
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
fi

rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

docker run -d \
    --name adguardhome \
    -v "$ADGUARD_DIR/work:/opt/adguardhome/work" \
    -v "$ADGUARD_DIR/conf:/opt/adguardhome/conf" \
    -p 53:53/tcp \
    -p 53:53/udp \
    -p 80:80 \
    -p 443:443 \
    -p 3000:3000 \
    --restart unless-stopped \
    --dns=8.8.8.8 \
    --dns=8.8.4.4 \
    adguard/adguardhome
