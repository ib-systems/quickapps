#!/bin/bash

set -e

export HOME=/root

apt-get update
apt-get install -y curl ca-certificates

curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup

if ! command -v hermes >/dev/null 2>&1; then
    echo
    echo -e "\033[0;31m\033[1mERROR:\033[0m Hermes Agent installation failed."
    echo
    exit 1
fi

cat > /usr/local/bin/hermes-setup <<'EOF'
#!/bin/bash

set -e

export HOME=/root

hermes setup

rm -f /etc/hermes-preinstall
rm -f /etc/profile.d/hermes-setup.sh

echo
echo -e "\033[0;32m\033[1m==========================================\033[0m"
echo -e "\033[0;32m\033[1m Hermes Agent setup completed\033[0m"
echo -e "\033[0;32m\033[1m==========================================\033[0m"
echo
EOF

chmod +x /usr/local/bin/hermes-setup

touch /etc/hermes-preinstall

cat > /etc/profile.d/hermes-setup.sh <<'EOF'
if [ -f /etc/hermes-preinstall ] && [ -t 1 ] && command -v hermes >/dev/null 2>&1; then
    echo
    echo -e "\033[0;36m\033[1m==========================================\033[0m"
    echo -e "\033[0;36m\033[1m Hermes Agent requires initial configuration\033[0m"
    echo -e "\033[0;36m\033[1m==========================================\033[0m"
    echo
    echo -e "\033[1;33mRun the following command to complete setup:\033[0m"
    echo
    echo -e "    \033[1;33mhermes-setup\033[0m"
    echo
    echo -e "\033[0;36m\033[1m==========================================\033[0m"
    echo
fi
EOF

echo
echo -e "\033[0;32m\033[1m==========================================\033[0m"
echo -e "\033[0;32m\033[1m Hermes Agent preinstall completed\033[0m"
echo -e "\033[0;32m\033[1m==========================================\033[0m"
echo
echo -e "\033[1;33mAfter connecting via SSH, run:\033[0m"
echo
echo -e "    \033[1;33mhermes-setup\033[0m"
echo
echo -e "\033[0;32m\033[1m==========================================\033[0m"
echo
