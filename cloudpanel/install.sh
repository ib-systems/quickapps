#!/bin/bash

set -e

apt-get update
apt-get install -y curl wget sudo

curl -sS https://installer.cloudpanel.io/ce/v2/install.sh -o install.sh

echo "8146dbe0a488e7088b04071b0c34d59aa0ab1fe9dcec382d395fd155c9e6c476 install.sh" | sha256sum -c

DB_ENGINE=MYSQL_8.4 bash install.sh

IP_ADDRESS="$(hostname -I | awk '{print $1}')"

echo
echo "=========================================="
echo " CloudPanel installation completed"
echo "=========================================="
echo
echo "URL : https://${IP_ADDRESS}:8443"
echo
echo "=========================================="
