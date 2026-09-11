#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/redmine
cd /opt/redmine

POSTGRES_PASSWORD=$(openssl rand -hex 24)

cat > .env <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF

cat > docker-compose.yml <<'EOF'
services:

  redmine:
    image: redmine:7.0.1
    container_name: redmine
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      REDMINE_DB_POSTGRES: postgres
      REDMINE_DB_DATABASE: redmine
      REDMINE_DB_USERNAME: redmine
      REDMINE_DB_PASSWORD: ${POSTGRES_PASSWORD}
    depends_on:
      - postgres
    volumes:
      - redmine_files:/usr/src/redmine/files
      - redmine_plugins:/usr/src/redmine/plugins
      - redmine_themes:/usr/src/redmine/public/themes

  postgres:
    image: postgres:16
    container_name: redmine_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: redmine
      POSTGRES_USER: redmine
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  redmine_files:
  redmine_plugins:
  redmine_themes:
  postgres_data:
EOF

docker compose pull
docker compose up -d
