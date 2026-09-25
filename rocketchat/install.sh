#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

set -e

IPv4=$(hostname -I | awk '{print $1}')

apt-get update
apt-get install -y curl

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker

mkdir -p /opt/rocketchat
cd /opt/rocketchat

cat <<EOF > docker-compose.yml
services:
  rocketchat:
    image: rocketchat/rocket.chat:latest
    restart: unless-stopped
    volumes:
      - ./uploads:/app/uploads
    environment:
      PORT: "3000"
      ROOT_URL: http://$IPv4:3000
      MONGO_URL: mongodb://mongo:27017/rocketchat?replicaSet=rs0
      MONGO_OPLOG_URL: mongodb://mongo:27017/local?replicaSet=rs0
    depends_on:
      - mongo-init-replica
    ports:
      - "3000:3000"

  mongo:
    image: mongo:8.0
    restart: unless-stopped
    command: mongod --oplogSize 128 --replSet rs0 --storageEngine=wiredTiger
    volumes:
      - ./data/db:/data/db

  mongo-init-replica:
    image: mongo:8.0
    depends_on:
      - mongo
    entrypoint: >
      bash -c '
        echo "Waiting for MongoDB...";
        for i in {1..30}; do
          if mongosh --host mongo:27017 --eval "db.adminCommand(\"ping\")" >/dev/null 2>&1; then
            echo "MongoDB is up, initiating replica set";
            mongosh --host mongo:27017 --eval "
              rs.initiate({
                _id: \"rs0\",
                members: [{ _id: 0, host: \"mongo:27017\" }]
              })"
            exit 0;
          fi
          sleep 2;
        done
        echo "Timed out waiting for MongoDB"
        exit 1;
      '

EOF

docker compose up -d

sleep 60

echo
echo "========================================"
echo "Rocket.Chat installation completed"
echo "========================================"
echo
echo "Access URL: http://$IPv4:3000"
echo
