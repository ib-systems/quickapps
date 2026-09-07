#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

apt-get install -y docker-compose-plugin

systemctl enable --now docker

mkdir -p /opt/wiki-js
cd /opt/wiki-js

POSTGRES_PASSWORD=$(openssl rand -hex 24)

cat > .env <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF

cat > docker-compose.yml <<'EOF'
services:

  db:
    image: postgres:17-alpine
    container_name: wiki_js_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: wiki
      POSTGRES_USER: wikijs
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db_data:/var/lib/postgresql/data

  wiki:
    image: ghcr.io/requarks/wiki:2
    container_name: wiki_js
    restart: unless-stopped
    depends_on:
      - db
    ports:
      - "8080:3000"
    environment:
      DB_TYPE: postgres
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: wikijs
      DB_PASS: ${POSTGRES_PASSWORD}
      DB_NAME: wiki

volumes:
  db_data:
EOF

docker compose pull
docker compose up -d
