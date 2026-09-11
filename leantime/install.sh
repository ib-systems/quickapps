#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates openssl git

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/leantime
cd /opt/leantime

DB_PASSWORD=$(openssl rand -hex 24)
SESSION_PASSWORD=$(openssl rand -hex 32)

cat > .env <<EOF
LEAN_PORT=8080
LEAN_APP_URL=
LEAN_APP_DIR=
LEAN_DEBUG=0

MYSQL_ROOT_PASSWORD=${DB_PASSWORD}
MYSQL_DATABASE=leantime
MYSQL_USER=lean
MYSQL_PASSWORD=${DB_PASSWORD}

LEAN_DB_HOST=mysql_leantime
LEAN_DB_USER=lean
LEAN_DB_PASSWORD=${DB_PASSWORD}
LEAN_DB_DATABASE=leantime
LEAN_DB_PORT=3306

LEAN_SESSION_PASSWORD=${SESSION_PASSWORD}
LEAN_SESSION_EXPIRATION=28800
LEAN_SESSION_SECURE=false

LEAN_SITENAME=Leantime
LEAN_LANGUAGE=en-US
LEAN_DEFAULT_TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone)

LEAN_USER_FILE_PATH=userfiles/
LEAN_DB_BACKUP_PATH=backupdb/
EOF

cat > docker-compose.yml <<'EOF'
services:

  leantime_db:
    image: mysql:8.4
    container_name: mysql_leantime
    restart: unless-stopped
    volumes:
      - db_data:/var/lib/mysql
    env_file:
      - ./.env
    networks:
      - leantime-net
    command: --character-set-server=UTF8MB4 --collation-server=UTF8MB4_unicode_ci
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

  leantime:
    image: leantime/leantime:latest
    container_name: leantime
    restart: unless-stopped
    env_file:
      - ./.env
    security_opt:
      - no-new-privileges:true
    cap_add:
      - CAP_CHOWN
      - CAP_SETGID
      - CAP_SETUID
    ports:
      - "${LEAN_PORT}:8080"
    networks:
      - leantime-net
    volumes:
      - public_userfiles:/var/www/html/public/userfiles
      - userfiles:/var/www/html/userfiles
      - plugins:/var/www/html/app/Plugins
      - logs:/var/www/html/storage/logs
    depends_on:
      leantime_db:
        condition: service_healthy

volumes:
  db_data:
  userfiles:
  public_userfiles:
  plugins:
  logs:

networks:
  leantime-net:
EOF

docker compose pull
docker compose up -d
