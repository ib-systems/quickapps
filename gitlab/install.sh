#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/gitlab/config
mkdir -p /opt/gitlab/logs
mkdir -p /opt/gitlab/data

docker run -d \
    --hostname "$(hostname -f)" \
    --name gitlab \
    --restart always \
    --publish 80:80 \
    --publish 443:443 \
    --publish 2222:22 \
    --volume /opt/gitlab/config:/etc/gitlab \
    --volume /opt/gitlab/logs:/var/log/gitlab \
    --volume /opt/gitlab/data:/var/opt/gitlab \
    --shm-size 256m \
    gitlab/gitlab-ce:latest
