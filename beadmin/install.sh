#!/bin/bash
set -e

EMAIL="admin@example.com"
IPv4=$(hostname -I | awk '{print $1}')

apt-get update -y
apt-get install -y wget curl

wget -O /etc/apt/trusted.gpg.d/beadmin-nexus-public.gpg \
    "https://nexus.beadmin.com/repository/public-keys/beadmin-nexus-public.gpg"

chmod 644 /etc/apt/trusted.gpg.d/beadmin-nexus-public.gpg

echo "deb [signed-by=/etc/apt/trusted.gpg.d/beadmin-nexus-public.gpg] https://nexus.beadmin.com/repository/beadmin/ stable main" \
    > /etc/apt/sources.list.d/beadmin.list

echo "beadmin beadmin/ssl_acme_domain string ${IPv4}" | debconf-set-selections
echo "beadmin beadmin/default_user string ${EMAIL}" | debconf-set-selections
echo "beadmin beadmin/default_password password ${PASSWORD}" | debconf-set-selections

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends beadmin

systemctl enable --now beadmin

echo
echo "======================================"
echo "BeAdmin installation completed"
echo "======================================"
echo
echo "URL: https://${IPv4}/"
echo "Email: ${EMAIL}"
echo
systemctl status beadmin --no-pager
