#!/bin/bash
set -e

DOLIBARR_DIR="/opt/dolibarr"
DOLIBARR_SECRETS_DIR="${DOLIBARR_DIR}/secrets"

# Docker
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

# Directories
mkdir -p \
    "${DOLIBARR_DIR}/documents" \
    "${DOLIBARR_DIR}/custom" \
    "${DOLIBARR_DIR}/mariadb" \
    "${DOLIBARR_SECRETS_DIR}"

# Generate passwords
openssl rand -base64 48 | tr -d '\n' > "${DOLIBARR_SECRETS_DIR}/MYSQL_ROOT_PASSWORD"
openssl rand -base64 48 | tr -d '\n' > "${DOLIBARR_SECRETS_DIR}/MYSQL_PASSWORD"
openssl rand -base64 48 | tr -d '\n' > "${DOLIBARR_SECRETS_DIR}/DOLIBARR_PASSWORD"

chmod 600 "${DOLIBARR_SECRETS_DIR}"/*

# Docker Compose
cat > "${DOLIBARR_DIR}/docker-compose.yml" <<'EOF'
services:

  mariadb:
    image: docker.io/library/mariadb:11.8
    container_name: dolibarr-mariadb
    restart: unless-stopped

    environment:
      MARIADB_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password
      MARIADB_DATABASE: dolidb
      MARIADB_USER: dolidbuser
      MARIADB_PASSWORD_FILE: /run/secrets/mysql_password

    secrets:
      - mysql_root_password
      - mysql_password

    volumes:
      - ./mariadb:/var/lib/mysql

  dolibarr:
    image: docker.io/dolibarr/dolibarr:24.0.0
    container_name: dolibarr
    restart: unless-stopped

    depends_on:
      - mariadb

    environment:
      DOLI_INSTALL_AUTO: "1"
      DOLI_PROD: "1"

      DOLI_DB_TYPE: mysqli
      DOLI_DB_HOST: mariadb
      DOLI_DB_HOST_PORT: "3306"
      DOLI_DB_NAME: dolidb
      DOLI_DB_USER: dolidbuser
      DOLI_DB_PASSWORD_FILE: /run/secrets/dolibarr_db_password

      DOLI_URL_ROOT: "http://0.0.0.0"

      DOLI_ADMIN_LOGIN: admin
      DOLI_ADMIN_PASSWORD_FILE: /run/secrets/dolibarr_admin_password

      DOLI_INIT_DEMO: "0"

      PHP_INI_DATE_TIMEZONE: Europe/Helsinki

    secrets:
      - dolibarr_db_password
      - dolibarr_admin_password

    ports:
      - "80:80"

    volumes:
      - ./documents:/var/www/documents
      - ./custom:/var/www/html/custom

    command: ["apache2-foreground"]

secrets:
  mysql_root_password:
    file: ./secrets/MYSQL_ROOT_PASSWORD

  mysql_password:
    file: ./secrets/MYSQL_PASSWORD

  dolibarr_db_password:
    file: ./secrets/MYSQL_PASSWORD

  dolibarr_admin_password:
    file: ./secrets/DOLIBARR_PASSWORD
EOF

chmod 600 "${DOLIBARR_DIR}/docker-compose.yml"

cd "${DOLIBARR_DIR}"

docker compose pull
docker compose up -d

echo
echo "======================================"
echo "Dolibarr installation completed"
echo "======================================"
echo
echo "URL: http://$(hostname -I | awk '{print $1}')/"
echo "Login: admin"
echo "Password file: ${DOLIBARR_SECRETS_DIR}/DOLIBARR_PASSWORD"
echo
docker compose ps
