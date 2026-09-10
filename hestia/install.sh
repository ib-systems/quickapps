#!/bin/bash

set -e

apt-get update
apt-get install -y wget curl ca-certificates

wget https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh \
    -O /tmp/hst-install.sh

chmod +x /tmp/hst-install.sh

bash /tmp/hst-install.sh \
    --force \
    --interactive no \
    --hostname "$(hostname -f)" \
    --email "admin@localhost" \
    --username "hestiaadmin" \
    --password "$HESTIA_PASSWORD"
