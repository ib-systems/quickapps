#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

docker volume create gitea_data

docker run -d \
    --name gitea \
    --restart always \
    -p 3000:3000 \
    -p 222:22 \
    -v gitea_data:/data \
    docker.gitea.com/gitea:latest
