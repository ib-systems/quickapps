#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/passbolt
cd /opt/passbolt

MYSQL_PASSWORD=$(openssl rand -hex 24)
APP_FULL_BASE_URL="http://$(hostname -I | awk '{print $1}'):8080"

cat > .env <<EOF
MYSQL_PASSWORD=${MYSQL_PASSWORD}
APP_FULL_BASE_URL=${APP_FULL_BASE_URL}
EOF

cat > docker-compose.yml <<'EOF'
services:

  db:
    image: mariadb:10.11
    container_name: passbolt_db
    restart: unless-stopped
    environment:
      MYSQL_RANDOM_ROOT_PASSWORD: "true"
      MYSQL_DATABASE: "passbolt"
      MYSQL_USER: "passbolt"
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - database_volume:/var/lib/mysql

  passbolt:
    image: passbolt/passbolt:latest-ce
    container_name: passbolt
    restart: unless-stopped
    depends_on:
      - db
    environment:
      APP_FULL_BASE_URL: ${APP_FULL_BASE_URL}
      DATASOURCES_DEFAULT_HOST: "db"
      DATASOURCES_DEFAULT_USERNAME: "passbolt"
      DATASOURCES_DEFAULT_PASSWORD: ${MYSQL_PASSWORD}
      DATASOURCES_DEFAULT_DATABASE: "passbolt"
    volumes:
      - gpg_volume:/etc/passbolt/gpg
      - jwt_volume:/etc/passbolt/jwt
    command:
      [
        "/usr/bin/wait-for.sh",
        "-t",
        "0",
        "db:3306",
        "--",
        "/docker-entrypoint.sh"
      ]
    ports:
      - "8080:80"

volumes:
  database_volume:
  gpg_volume:
  jwt_volume:
EOF

docker compose pull
docker compose up -d
