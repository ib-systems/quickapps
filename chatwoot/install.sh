#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

IP=$(hostname -I | awk '{print $1}')
POSTGRES_PASSWORD=$(openssl rand -hex 16)

apt-get update
apt-get install -y curl openssl

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/chatwoot
cd /opt/chatwoot

docker pull chatwoot/chatwoot:latest

SECRET_KEY_BASE=$(docker run --rm chatwoot/chatwoot:latest bundle exec rails secret)

cat <<EOF > docker-compose.yml
services:
  postgres:
    image: pgvector/pgvector:pg16
    restart: always
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: chatwoot
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - redisdata:/data

  rails:
    image: chatwoot/chatwoot:latest
    restart: always
    depends_on:
      - postgres
      - redis
    volumes:
      - storage_data:/app/storage
    environment:
      RAILS_ENV: production
      NODE_ENV: production
      INSTALLATION_ENV: docker
      POSTGRES_HOST: postgres
      POSTGRES_PORT: "5432"
      POSTGRES_DATABASE: chatwoot
      POSTGRES_USERNAME: postgres
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      DATABASE_URL: postgres://postgres:$POSTGRES_PASSWORD@postgres:5432/chatwoot
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY_BASE: $SECRET_KEY_BASE
      FRONTEND_URL: http://$IP:3000
      DEFAULT_LOCALE: en
    ports:
      - "3000:3000"
    entrypoint: docker/entrypoints/rails.sh
    command: bundle exec rails s -p 3000 -b 0.0.0.0

  sidekiq:
    image: chatwoot/chatwoot:latest
    restart: always
    depends_on:
      - postgres
      - redis
    volumes:
      - storage_data:/app/storage
    environment:
      RAILS_ENV: production
      NODE_ENV: production
      INSTALLATION_ENV: docker
      POSTGRES_HOST: postgres
      POSTGRES_PORT: "5432"
      POSTGRES_DATABASE: chatwoot
      POSTGRES_USERNAME: postgres
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      DATABASE_URL: postgres://postgres:$POSTGRES_PASSWORD@postgres:5432/chatwoot
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY_BASE: $SECRET_KEY_BASE
    command: bundle exec sidekiq -C config/sidekiq.yml

volumes:
  pgdata:
  redisdata:
  storage_data:
EOF

docker compose up -d postgres redis

sleep 15

docker compose run --rm rails bundle exec rails db:chatwoot_prepare

docker compose up -d

echo "Access URL: http://$IP:3000"
