#!/bin/bash

set -euo pipefail

FORGEJO_DIR="/opt/forgejo"
FORGEJO_VERSION="16"

DB_NAME="forgejo"
DB_USER="forgejo"
DB_PASSWORD="$(openssl rand -hex 24)"

ADMIN_USER="administrator"
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"

apt-get update -y
apt-get install -y ca-certificates curl openssl

if ! command -v docker >/dev/null 2>&1
then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p "$FORGEJO_DIR"

cat > "$FORGEJO_DIR/docker-compose.yml" <<EOF
services:

  forgejo:
    image: codeberg.org/forgejo/forgejo:${FORGEJO_VERSION}
    container_name: forgejo
    restart: unless-stopped

    environment:
      USER_UID: 1000
      USER_GID: 1000

      FORGEJO__security__INSTALL_LOCK: "true"

      FORGEJO__database__DB_TYPE: postgres
      FORGEJO__database__HOST: forgejo-db:5432
      FORGEJO__database__NAME: ${DB_NAME}
      FORGEJO__database__USER: ${DB_USER}
      FORGEJO__database__PASSWD: ${DB_PASSWORD}

      FORGEJO__server__SSH_PORT: 2222
      FORGEJO__server__SSH_LISTEN_PORT: 22

    volumes:
      - forgejo_data:/data
      - /etc/localtime:/etc/localtime:ro

    ports:
      - "3000:3000"
      - "2222:22"

    networks:
      - forgejo

    depends_on:
      forgejo-db:
        condition: service_healthy

  forgejo-db:
    image: postgres:14
    container_name: forgejo-db
    restart: unless-stopped

    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}

    volumes:
      - postgres_data:/var/lib/postgresql/data

    networks:
      - forgejo

    healthcheck:
      test:
        [
          "CMD-SHELL",
          "pg_isready -U ${DB_USER} -d ${DB_NAME}"
        ]
      interval: 10s
      timeout: 5s
      retries: 30

networks:
  forgejo:
    driver: bridge

volumes:
  forgejo_data:
  postgres_data:
EOF

cd "$FORGEJO_DIR"

docker compose up -d

echo "Waiting for Forgejo..."

until curl -fsS http://127.0.0.1:3000/ >/dev/null 2>&1
do
    sleep 5
done

echo "Forgejo is ready."

echo "Migrating Forgejo database..."

docker exec --user 1000 forgejo \
    forgejo migrate

echo "Creating admin user..."

if ! docker exec --user 1000 forgejo \
    forgejo admin user list 2>/dev/null |
    grep -q "$ADMIN_USER"
then
    docker exec --user 1000 forgejo \
        forgejo admin user create \
        --admin \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASSWORD" \
        --email "$ADMIN_EMAIL" \
        --must-change-password=false
fi

echo
echo "Forgejo installed successfully."
echo
echo "URL: http://$(hostname -I | awk '{print $1}'):3000"
echo "SSH: ssh://git@$(hostname -I | awk '{print $1}'):2222"
echo
echo "Username: $ADMIN_USER"
echo "Email: $ADMIN_EMAIL"
