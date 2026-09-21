#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

# Configuration
MAILCOW_DIR="/opt/mailcow-dockerized"
IP_ADDRESS="$(hostname -I | awk '{print $1}')"
TIMEZONE="$(cat /etc/timezone 2>/dev/null || echo UTC)"

# Install required packages
apt-get update
apt-get install -y curl pwgen git ca-certificates

# Install Docker
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

# Install Mailcow
mkdir -p /opt
git clone https://github.com/mailcow/mailcow-dockerized "$MAILCOW_DIR"

cd "$MAILCOW_DIR"

# Generate passwords
DBPASS="$(pwgen 16 1)"
DBROOTPASS="$(pwgen 16 1)"
REDISPASS="$(pwgen 16 1)"

# Create Mailcow configuration
cat > mailcow.conf <<EOF
MAILCOW_HOSTNAME=$IP_ADDRESS
MAILCOW_PASS_SCHEME=BLF-CRYPT

DBNAME=mailcow
DBUSER=mailcow
DBPASS=$DBPASS
DBROOT=$DBROOTPASS

REDISPASS=$REDISPASS

HTTP_PORT=80
HTTP_BIND=0.0.0.0
HTTPS_PORT=443
HTTPS_BIND=0.0.0.0
HTTP_REDIRECT=n

SMTP_PORT=25
SMTPS_PORT=465
SUBMISSION_PORT=587
IMAP_PORT=143
IMAPS_PORT=993
POP_PORT=110
POPS_PORT=995
SIEVE_PORT=4190
DOVEADM_PORT=127.0.0.1:19991
SQL_PORT=127.0.0.1:13306
REDIS_PORT=127.0.0.1:7654

TZ=$TIMEZONE
COMPOSE_PROJECT_NAME=mailcowdockerized
DOCKER_COMPOSE_VERSION=native

SKIP_LETS_ENCRYPT=y
USE_WATCHDOG=y
WATCHDOG_NOTIFY_START=y
EOF

# Install default SSL certificate
mkdir -p data/assets/ssl
cp -n data/assets/ssl-example/cert.pem data/assets/ssl/cert.pem
cp -n data/assets/ssl-example/key.pem data/assets/ssl/key.pem

# Start Mailcow
docker compose pull
docker compose up -d

echo ""
echo "=========================================="
echo " Mailcow installation completed"
echo "=========================================="
echo ""
echo "Admin URL : https://${IP_ADDRESS}/admin"
echo "Username  : admin"
echo "Password  : moohoo"
echo ""
echo "=========================================="
