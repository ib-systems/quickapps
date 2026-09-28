#!/bin/bash

set -euo pipefail

STRAPI_DIR="/opt/strapi"
STRAPI_APP_DIR="$STRAPI_DIR/app"

DB_NAME="strapi_db"
DB_USER="strapi_user"
DB_PASSWORD="$(openssl rand -hex 24)"
MYSQL_ROOT_PASSWORD="$(openssl rand -hex 24)"

STRAPI_APP_KEYS="$(openssl rand -base64 32),$(openssl rand -base64 32),$(openssl rand -base64 32),$(openssl rand -base64 32)"
API_TOKEN_SALT="$(openssl rand -base64 32)"
ADMIN_JWT_SECRET="$(openssl rand -base64 32)"
TRANSFER_TOKEN_SALT="$(openssl rand -base64 32)"
JWT_SECRET="$(openssl rand -base64 32)"
ENCRYPTION_KEY="$(openssl rand -base64 32)"

apt-get update -y
apt-get install -y ca-certificates curl openssl

if ! command -v docker >/dev/null 2>&1
then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p "$STRAPI_APP_DIR"

echo "Creating Strapi project..."

docker run --rm \
    -v "$STRAPI_APP_DIR:/app" \
    -w /app \
    node:22-bookworm \
    bash -c '
        npx --yes create-strapi-app@latest . \
            --non-interactive \
            --typescript \
            --use-npm \
            --dbclient mysql \
            --dbhost strapi-db \
            --dbport 3306 \
            --dbname strapi_db \
            --dbusername strapi_user \
            --dbpassword temporary_password \
            --dbssl false \
            --install \
            --no-run \
            --no-git-init \
            --skip-cloud
    '

test -f "$STRAPI_APP_DIR/package.json"

cat > "$STRAPI_APP_DIR/.env" <<EOF
HOST=0.0.0.0
PORT=1337

APP_KEYS=$STRAPI_APP_KEYS
API_TOKEN_SALT=$API_TOKEN_SALT
ADMIN_JWT_SECRET=$ADMIN_JWT_SECRET
TRANSFER_TOKEN_SALT=$TRANSFER_TOKEN_SALT
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY

DATABASE_CLIENT=mysql
DATABASE_HOST=strapi-db
DATABASE_PORT=3306
DATABASE_NAME=$DB_NAME
DATABASE_USERNAME=$DB_USER
DATABASE_PASSWORD=$DB_PASSWORD
DATABASE_SSL=false

NODE_ENV=production
EOF

chmod 600 "$STRAPI_APP_DIR/.env"

cat > "$STRAPI_DIR/Dockerfile" <<'EOF'
FROM node:22-alpine AS build

RUN apk add --no-cache \
    build-base \
    gcc \
    autoconf \
    automake \
    zlib-dev \
    libpng-dev \
    bash \
    vips-dev \
    git

WORKDIR /opt/

COPY app/package.json app/package-lock.json ./

RUN npm install -g node-gyp

RUN npm config set fetch-retry-maxtimeout 600000 -g

RUN npm ci

ENV PATH=/opt/node_modules/.bin:$PATH

WORKDIR /opt/app

COPY app/ .

ENV NODE_ENV=production

RUN npm run build


FROM node:22-alpine

RUN apk add --no-cache vips-dev

ENV NODE_ENV=production

WORKDIR /opt/

COPY --from=build /opt/package.json /opt/package-lock.json ./

RUN npm ci --omit=dev && npm cache clean --force

ENV PATH=/opt/node_modules/.bin:$PATH

WORKDIR /opt/app

COPY --from=build /opt/app ./

RUN chown -R node:node /opt/app

USER node

EXPOSE 1337

HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=60s \
    --retries=5 \
    CMD wget --quiet --tries=1 --spider http://localhost:1337/_health || exit 1

CMD ["npm", "run", "start"]
EOF

cat > "$STRAPI_DIR/docker-compose.yml" <<EOF
services:

  strapi:
    container_name: strapi
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file:
      - ./app/.env
    ports:
      - "1337:1337"
    volumes:
      - strapi_uploads:/opt/app/public/uploads
    depends_on:
      strapi-db:
        condition: service_healthy
    networks:
      - strapi

  strapi-db:
    container_name: strapi-db
    image: mysql:8.4
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: $DB_NAME
      MYSQL_USER: $DB_USER
      MYSQL_PASSWORD: $DB_PASSWORD
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test:
        [
          "CMD",
          "mysqladmin",
          "ping",
          "-h",
          "localhost",
          "-u",
          "root",
          "-p$MYSQL_ROOT_PASSWORD"
        ]
      interval: 10s
      timeout: 5s
      retries: 30
    networks:
      - strapi

volumes:
  mysql_data:
  strapi_uploads:

networks:
  strapi:
    driver: bridge
EOF

cd "$STRAPI_DIR"

docker compose build --no-cache
docker compose up -d

sleep 120

cat > /root/strapi-credentials.txt <<EOF
Strapi

URL:
http://$(hostname -I | awk '{print $1}'):1337/admin

Database:
$DB_NAME

Database User:
$DB_USER

Database Password:
$DB_PASSWORD

Database Host:
strapi-db

Database Port:
3306

MySQL Root Password:
$MYSQL_ROOT_PASSWORD
EOF

chmod 600 /root/strapi-credentials.txt

echo
echo "======================================"
echo "Strapi installed successfully."
echo "======================================"
echo
echo "URL:"
echo "http://$(hostname -I | awk '{print $1}'):1337/admin"
echo
echo "Credentials:"
echo "/root/strapi-credentials.txt"
echo
echo "Check containers:"
docker compose ps
