#!/bin/bash

set -euo pipefail

DASHY_DIR="/opt/dashy"

apt-get update -y
apt-get install -y ca-certificates curl

if ! command -v docker >/dev/null 2>&1
then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker is already installed."
fi

systemctl enable --now docker

mkdir -p "$DASHY_DIR"

cat > "$DASHY_DIR/conf.yml" <<'EOF'
pageInfo:
  title: Dashy
  description: Welcome to your new dashboard!
  navLinks:
    - title: GitHub
      path: https://github.com/Lissy93/dashy
    - title: Documentation
      path: https://dashy.to/docs

appConfig:
  theme: colorful

sections:
  - name: Getting Started
    icon: fas fa-rocket
    items:
      - title: Dashy Live
        description: Development & project management links for Dashy
        icon: https://i.ibb.co/qWWpD0v/astro-dab-128.png
        url: https://live.dashy.to/
        target: newtab

      - title: GitHub
        description: Source Code, Issues and Pull Requests
        url: https://github.com/lissy93/dashy
        icon: favicon

      - title: Docs
        description: Read the documentation
        url: https://dashy.to/docs
        icon: favicon
EOF

docker run -d \
    -p 8080:8080 \
    -v "$DASHY_DIR/conf.yml:/app/user-data/conf.yml" \
    --name my-dashboard \
    --restart=always \
    lissy93/dashy:latest
