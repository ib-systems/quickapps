#!/bin/bash

set -euo pipefail

POCKETBASE_DIR="/home/pocketbase"
POCKETBASE_VERSION="0.26.1"
EMAIL="admin@example.com"
PASSWORD="${PASSWORD:?PASSWORD is required}"

apt-get update -y
apt-get install -y ca-certificates curl unzip

if ! id pocketbase >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin pocketbase
fi

mkdir -p "$POCKETBASE_DIR"
cd "$POCKETBASE_DIR"

curl -fsSL \
    -o pocketbase.zip \
    "https://github.com/pocketbase/pocketbase/releases/download/v${POCKETBASE_VERSION}/pocketbase_${POCKETBASE_VERSION}_linux_amd64.zip"

unzip -o pocketbase.zip
rm -f pocketbase.zip

chown -R pocketbase:pocketbase "$POCKETBASE_DIR"
chmod 750 "$POCKETBASE_DIR"
chmod 750 "$POCKETBASE_DIR/pocketbase"

runuser -u pocketbase -- "$POCKETBASE_DIR/pocketbase" \
    --dir "$POCKETBASE_DIR" \
    superuser upsert "$EMAIL" "$PASSWORD"

cat > /etc/systemd/system/pocketbase.service <<'EOF'
[Unit]
Description=PocketBase service
After=network.target

[Service]
Type=simple
User=pocketbase
Group=pocketbase
WorkingDirectory=/home/pocketbase
ExecStart=/home/pocketbase/pocketbase serve --dir=/home/pocketbase --http=0.0.0.0:8090
Restart=always
RestartSec=5
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now pocketbase

echo
echo "PocketBase installed successfully."
echo "Admin URL: http://$(hostname -I | awk '{print $1}'):8090/_/"
echo "Username: $EMAIL"
