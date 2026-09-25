#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

set -e

IPv4=$(hostname -I | awk '{print $1}')
secret=$(openssl rand -hex 32)

apt-get update
apt-get install -y curl openssl

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/openproject
cd /opt/openproject

cat <<EOF > docker-compose.yml
services:
  openproject:
    image: openproject/openproject:16.6
    restart: always
    ports:
      - "8080:8080"
    environment:
      - SECRET_KEY_BASE=$secret
      - DATABASE_URL=postgresql://openproject:openprojectpass@db:5432/openproject
      - OPENPROJECT_HTTPS=false
      - FORCE_SSL=false
    depends_on:
      - db
    volumes:
      - openproject_data:/var/openproject/assets

  db:
    image: postgres:17
    restart: always
    environment:
      - POSTGRES_DB=openproject
      - POSTGRES_USER=openproject
      - POSTGRES_PASSWORD=openprojectpass
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  openproject_data:
  pgdata:
EOF

docker compose up -d

sleep 240

echo
echo "========================================"
echo "OpenProject installation completed"
echo "========================================"
echo
echo "Access URL: http://$IPv4:8080"
echo "Username: admin"
echo "Password: admin"
echo
