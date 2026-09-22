#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl wget

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
fi

POSTGRES_PASSWORD=$(openssl rand -hex 16)

mkdir -p /data/safeline
cd /data/safeline

wget -q https://waf.chaitin.com/release/latest/compose.yaml

cat > .env <<EOF
SAFELINE_DIR=/data/safeline
IMAGE_TAG=latest
MGT_PORT=9443
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
SUBNET_PREFIX=172.22.222
IMAGE_PREFIX=chaitin
ARCH_SUFFIX=
RELEASE=
REGION=-g
EOF

docker compose up -d

until [ "$(docker inspect -f '{{.State.Health.Status}}' safeline-mgt 2>/dev/null)" = "healthy" ]; do
    sleep 5
done

RESET_OUTPUT=$(docker exec safeline-mgt resetadmin 2>&1)

UI_PASSWORD=$(printf '%s\n' "$RESET_OUTPUT" |
    sed 's/\x1b\[[0-9;]*m//g' |
    sed -n 's/.*Initial password[：:][[:space:]]*//p' |
    tail -n1 |
    xargs)

echo
echo "SafeLine installed"
echo "URL: https://$(hostname -I | awk '{print $1}'):9443/"
echo "Username: admin"
echo "Password: ${UI_PASSWORD}"
