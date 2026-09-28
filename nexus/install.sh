#!/bin/bash

set -euo pipefail

NEXUS_DIR="/opt/nexus"

# Update system
apt-get update -y
apt-get install -y ca-certificates curl

# Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

# Start Docker
systemctl enable --now docker

# Create Nexus directory
mkdir -p "$NEXUS_DIR"
cd "$NEXUS_DIR"

# Create Docker Compose file
cat > docker-compose.yml <<'EOF'
services:
  nexus:
    image: sonatype/nexus3:latest
    container_name: nexus
    restart: unless-stopped

    ports:
      - "8081:8081"

    volumes:
      - nexus-data:/nexus-data

    environment:
      INSTALL4J_ADD_VM_PARAMS: "-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g"

volumes:
  nexus-data:
    driver: local
EOF

# Start Nexus
docker compose up -d

# Wait for the initial admin password
echo "Waiting for Nexus to start..."

until docker exec nexus test -f /nexus-data/admin.password 2>/dev/null; do
    sleep 5
done

# Get initial admin password
password="$(docker exec nexus cat /nexus-data/admin.password)"

echo
echo "Nexus installed successfully."
echo
echo "Initial admin password:"
echo "$password"
echo
