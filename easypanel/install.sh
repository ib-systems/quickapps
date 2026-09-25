#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -e

IP=$(hostname -I | awk '{print $1}')

apt-get update
apt-get install -y curl

curl -sSL https://get.easypanel.io | sh

echo "Access URL: http://$IP"
