#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates

: "${RCLONE_PASSWORD:?}"

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | bash
fi

systemctl enable --now docker

apt-get install -y docker-compose-plugin

mkdir -p /opt/rclone
cd /opt/rclone

cat <<EOF > docker-compose.yml
services:
  rclone-webui:
    image: rclone/rclone:latest
    container_name: rclone-webui
    ports:
      - "5572:5572"
    volumes:
      - ./config:/config/rclone
      - ./data:/data
    command: rcd --rc-web-gui --rc-addr :5572 --rc-user admin --rc-pass ${RCLONE_PASSWORD}
    restart: unless-stopped
EOF

docker compose up -d

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

echo
echo "=========================================="
echo " Rclone WebUI installation completed"
echo "=========================================="
echo
echo "URL      : http://${IP_ADDRESS}:5572"
echo "Username : admin"
echo "Password : ${RCLONE_PASSWORD}"
echo
echo "=========================================="

docker compose ps
