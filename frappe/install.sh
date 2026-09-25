#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

set -e

EMAIL="admin@localhost.local"
IPv4=$(hostname -I | awk '{print $1}')

apt-get update
apt-get install -y wget python3

wget -q https://raw.githubusercontent.com/frappe/bench/develop/easy-install.py \
    -O /root/easy-install.py

python3 /root/easy-install.py deploy \
    --project=builder_prod_setup \
    --email="$EMAIL" \
    --image=ghcr.io/frappe/builder \
    --version=stable \
    --app=builder \
    --sitename="$IPv4" \
    --no-ssl \
    --http-port 80

PASSWORD_FILE="/root/builder_prod_setup-passwords.txt"

if [ ! -f "$PASSWORD_FILE" ]; then
    echo "ERROR: Password file was not found."
    exit 1
fi

ADMINISTRATOR_PASSWORD=$(grep '^ADMINISTRATOR_PASSWORD=' "$PASSWORD_FILE" | cut -d= -f2-)

echo
echo "========================================"
echo "Frappe Builder installation completed"
echo "========================================"
echo
echo "Login URL: http://$IPv4"
echo "Administrator password: $ADMINISTRATOR_PASSWORD"
echo
