#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl git

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

mkdir -p /opt/vert
cd /opt/vert

git clone https://github.com/VERT-sh/VERT.git .

docker build -t vert-sh/vert \
    --build-arg PUB_ENV=production \
    --build-arg PUB_HOSTNAME="${IP_ADDRESS}" \
    .

docker run -d \
    --restart unless-stopped \
    -p 3000:80 \
    --name vert \
    vert-sh/vert

echo
echo "=========================================="
echo " VERT installation completed"
echo "=========================================="
echo
echo "URL : http://${IP_ADDRESS}:3000"
echo
echo "=========================================="

docker ps
