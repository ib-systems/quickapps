#!/bin/bash

set -e

apt-get update
apt-get install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi


systemctl enable --now docker

mkdir -p /opt/jira
cd /opt/jira

cat > docker-compose.yml <<'EOF'
services:

  jira:
    image: atlassian/jira-software:8.20.30
    container_name: jira
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - jira_data:/var/atlassian/application-data/jira

volumes:
  jira_data:
EOF

docker compose pull
docker compose up -d
