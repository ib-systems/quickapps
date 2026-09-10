#!/bin/bash

wget https://autoinstall.plesk.com/plesk-installer -O /tmp/plesk-installer
chmod +x /tmp/plesk-installer

/tmp/plesk-installer install plesk

plesk bin admin --set-password -passwd "$PLESK_PASSWORD"
