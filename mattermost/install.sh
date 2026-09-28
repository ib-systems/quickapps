#!/bin/bash

set -euo pipefail

MATTERMOST_DIR="/opt/mattermost"

apt-get update -y
apt-get install -y ca-certificates curl openssl

if ! command -v docker >/dev/null 2>&1
then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | bash
else
    echo "Docker is already installed."
fi

systemctl enable --now docker

mkdir -p "$MATTERMOST_DIR"
cd "$MATTERMOST_DIR"

POSTGRES_PASSWORD=$(openssl rand -hex 24)
IP="$(hostname -I | awk '{print $1}')"

cat <<EOF > docker-compose.yml
services:
  db:
    image: postgres:13
    container_name: mattermost-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: mmuser
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_DB: mattermost
    volumes:
      - db_data:/var/lib/postgresql/data

  app:
    image: mattermost/mattermost-team-edition:latest
    container_name: mattermost
    restart: unless-stopped
    ports:
      - "8080:8065"
    volumes:
      - app_data:/mattermost/data
    environment:
      MM_SQLSETTINGS_DRIVERNAME: postgres
      MM_SQLSETTINGS_DATASOURCE: postgres://mmuser:$POSTGRES_PASSWORD@db:5432/mattermost?sslmode=disable
      MM_SERVICESETTINGS_SITEURL: http://$IP:8080
    depends_on:
      - db

volumes:
  db_data:
    driver: local
  app_data:
    driver: local
EOF

docker compose up -d

echo "Mattermost installed successfully."
echo "URL: http://$IP:8080"
