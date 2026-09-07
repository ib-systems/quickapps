#!/bin/bash

apt update
apt install -y wget curl

wget https://repo.fastpanel.direct/install_fastpanel.sh -O /tmp/install_fastpanel.sh
chmod +x /tmp/install_fastpanel.sh
/tmp/install_fastpanel.sh

mogwai chpasswd -u fastuser -p "$FASTPANEL_PASSWORD"
