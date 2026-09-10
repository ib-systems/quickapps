#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/stacks
mkdir -p /opt/dockge

curl -fsSL \
    https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml \
    -o /opt/dockge/compose.yaml

cd /opt/dockge

docker compose up -d
