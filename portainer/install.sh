#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

curl -fsSL https://get.docker.com | sh

systemctl enable --now docker

docker volume create portainer_data

docker run -d \
  --name portainer \
  --restart always \
  -p 8000:8000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
