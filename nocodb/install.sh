#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

set -e

IPv4=$(hostname -I | awk '{print $1}')

apt-get update
apt-get install -y curl openssl

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

password=$(openssl rand -base64 24)
jwt_secret=$(openssl rand -hex 32)

mkdir -p /opt/nocodb
cd /opt/nocodb

cat <<EOF > docker-compose.yml
services:
  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_USER: root
      POSTGRES_PASSWORD: $password
      POSTGRES_DB: d1
    volumes:
      - postgres_data:/var/lib/postgresql/data

  nocodb:
    image: nocodb/nocodb:latest
    restart: always
    ports:
      - "8080:8080"
    environment:
      NC_DB_TYPE: postgres
      NC_DB_HOST: postgres
      NC_DB_PORT: 5432
      NC_DB_USER: root
      NC_DB_PASSWORD: $password
      NC_DB_NAME: d1
      NC_AUTH_JWT_SECRET: $jwt_secret
    depends_on:
      - postgres
    volumes:
      - ./nocodb:/usr/app/data/

volumes:
  postgres_data:
EOF

docker compose up -d

echo
echo "========================================"
echo "NocoDB installation completed"
echo "========================================"
echo
echo "Access URL: http://$IPv4:8080"
echo
