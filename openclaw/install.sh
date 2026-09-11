#!/bin/bash

set -e

OPENCLAW_MARKER="/etc/openclaw-preinstall"
OPENCLAW_SETUP="/usr/local/bin/openclaw-setup"
OPENCLAW_PROFILE="/etc/profile.d/openclaw-setup.sh"

echo "=========================================="
echo " OpenClaw preinstall"
echo "=========================================="

# --------------------------------------------------
# Install dependencies
# --------------------------------------------------

apt-get update
apt-get install -y curl ca-certificates

# --------------------------------------------------
# Install OpenClaw
# --------------------------------------------------

echo "Installing OpenClaw..."

curl -fsSL --proto "=https" --tlsv1.2 \
    https://openclaw.ai/install.sh \
    | bash -s -- --no-onboard

# --------------------------------------------------
# Verify installation
# --------------------------------------------------

if ! command -v openclaw >/dev/null 2>&1; then
    echo
    echo "ERROR: OpenClaw installation failed."
    exit 1
fi

echo
echo "OpenClaw installed successfully:"
openclaw --version

# --------------------------------------------------
# Create setup command
# --------------------------------------------------

cat > "${OPENCLAW_SETUP}" <<'EOF'
#!/bin/bash

set -e

echo
echo "=========================================="
echo " OpenClaw initial setup"
echo "=========================================="
echo
echo "Starting OpenClaw onboarding..."
echo

openclaw onboard --install-daemon

echo
echo "=========================================="
echo " OpenClaw setup completed"
echo "=========================================="
echo

echo "Checking Gateway status..."
echo

openclaw gateway status || true

echo
echo "Useful commands:"
echo
echo "  openclaw status"
echo "  openclaw gateway status"
echo "  openclaw logs --follow"
echo

# Remove first-login notification
rm -f /etc/openclaw-preinstall
rm -f /etc/profile.d/openclaw-setup.sh

echo
echo "First-login setup notification has been removed."
echo

EOF

chmod 755 "${OPENCLAW_SETUP}"

# --------------------------------------------------
# Create preinstall marker
# --------------------------------------------------

touch "${OPENCLAW_MARKER}"
chmod 644 "${OPENCLAW_MARKER}"

# --------------------------------------------------
# Show setup instructions after SSH login
# --------------------------------------------------

cat > "${OPENCLAW_PROFILE}" <<'EOF'

if [ -f /etc/openclaw-preinstall ] && \
   [ -t 1 ] && \
   command -v openclaw >/dev/null 2>&1; then

    echo
    echo "=========================================="
    echo " OpenClaw requires initial configuration"
    echo "=========================================="
    echo
    echo "OpenClaw has been pre-installed."
    echo
    echo "Run the following command to complete setup:"
    echo
    echo "    openclaw-setup"
    echo
    echo "The OpenClaw onboarding wizard will guide"
    echo "you through the remaining configuration."
    echo
    echo "=========================================="
    echo

fi

EOF

chmod 644 "${OPENCLAW_PROFILE}"

# --------------------------------------------------
# Finished
# --------------------------------------------------

echo
echo "=========================================="
echo " OpenClaw preinstall completed"
echo "=========================================="
echo
echo "OpenClaw version:"
openclaw --version
echo
echo "The customer can now connect via SSH."
echo
echo "After login, run:"
echo
echo "    openclaw-setup"
echo
echo "=========================================="
echo
