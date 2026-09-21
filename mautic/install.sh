#!/bin/bash
set -e

MAUTIC_DIR="/opt/mautic"

mkdir -p "$MAUTIC_DIR"
cd "$MAUTIC_DIR"

PASSWORD=$(openssl rand -hex 16)
rootpass=$(openssl rand -hex 16)

apt-get update
apt-get install -y curl openssl

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

cat <<EOF > docker-compose.yml
services:
  mautic:
    image: mautic/mautic:latest
    container_name: mautic
    ports:
      - "8080:80"
    environment:
      MAUTIC_DB_HOST: mautic_db
      MAUTIC_DB_USER: mauticuser
      MAUTIC_DB_PASSWORD: $PASSWORD
      MAUTIC_DB_NAME: mautic
    depends_on:
      - db
    volumes:
      - mautic_data:/var/www/html

  db:
    image: mysql:8.4
    container_name: mautic_db
    environment:
      MYSQL_ROOT_PASSWORD: $rootpass
      MYSQL_DATABASE: mautic
      MYSQL_USER: mauticuser
      MYSQL_PASSWORD: $PASSWORD
    volumes:
      - db_data:/var/lib/mysql

volumes:
  mautic_data:
  db_data:
EOF

docker compose up -d

cat > /root/mautic-db.txt <<EOF
host: mautic_db
db_name: mautic
db_user: mauticuser
db_password: $PASSWORD
EOF

chmod 600 /root/mautic-db.txt

echo
echo "Mautic installed"
echo "URL: http://$(hostname -I | awk '{print $1}'):8080/"
echo
echo "Database credentials: /root/mautic-db.txt"
echo
