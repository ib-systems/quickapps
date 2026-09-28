#!/bin/bash

set -euo pipefail

apt-get update -y
apt-get install -y curl

curl -fsSL -o /root/install-ubuntu_6.0_en.sh \
    http://www.aapanel.com/script/install-ubuntu_6.0_en.sh

chmod +x /root/install-ubuntu_6.0_en.sh

echo "y" | /root/install-ubuntu_6.0_en.sh -u "Administrator" -p "$password"

url=$(grep 'aaPanel Internet Address' /root/aapanel.log | awk 'NR==1 {print $4}')

echo
echo "aaPanel installed successfully."
echo "URL: $url"
echo "Username: Administrator"
