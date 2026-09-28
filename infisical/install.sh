#!/bin/bash

set -euo pipefail

INFISICAL_DIR="/opt/infisical"

apt-get update -y
apt-get install -y ca-certificates curl openssl

if ! command -v docker >/dev/null 2>&1
then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker is already installed."
fi

systemctl enable --now docker

mkdir -p "$INFISICAL_DIR"
cd "$INFISICAL_DIR"

ENCRYPTION_KEY=$(openssl rand -hex 16)
AUTH_SECRET=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -hex 24)

cat <<EOF > .env
ENCRYPTION_KEY=$ENCRYPTION_KEY
AUTH_SECRET=$AUTH_SECRET

POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_USER=infisical
POSTGRES_DB=infisical

DB_CONNECTION_URI=postgres://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@db:5432/\${POSTGRES_DB}

REDIS_URL=redis://redis:6379
EOF

cat <<'EOF' > docker-compose.yml
services:
  backend:
    container_name: infisical-backend
    image: infisical/infisical:latest-postgres
    restart: unless-stopped
    pull_policy: always
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    env_file:
      - .env
    ports:
      - "80:8080"
    environment:
      NODE_ENV: production
    networks:
      - infisical

  redis:
    container_name: infisical-redis
    image: redis:latest
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - infisical

  db:
    container_name: infisical-db
    image: postgres:14-alpine
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - infisical
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 5s
      timeout: 10s
      retries: 10

volumes:
  pg_data:
    driver: local

  redis_data:
    driver: local

networks:
  infisical:
    driver: bridge
EOF

docker compose pull
docker compose up -d
