#!/bin/bash
#
# Non-interactive 3x-ui installer
# Wraps the official MHSanaei/3x-ui release for unattended deployment.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/<you>/openstack-kolla-configs/main/scripts/install-3xui.sh | bash
#
#   # Or with custom settings:
#   XUI_PORT=9443 XUI_USERNAME=myadmin XUI_PASSWORD=secret bash install-3xui.sh
#
# Environment variables (all optional — sane defaults are generated):
#   XUI_PORT        - Panel port              (default: random 1024-62000)
#   XUI_USERNAME    - Panel username           (default: random 10 chars)
#   XUI_PASSWORD    - Panel password           (default: random 10 chars)
#   XUI_BASEPATH    - Web base path            (default: random 18 chars)
#   XUI_VERSION     - Release tag, e.g. v2.6.0 (default: latest)
#   XUI_SSL         - SSL mode: ip | domain | skip  (default: ip)
#   XUI_SSL_DOMAIN  - Domain for SSL when XUI_SSL=domain
#   XUI_SSL_PORT    - ACME standalone port     (default: 80)
#   XUI_SSL_IPV6    - Optional IPv6 for IP cert
#   XUI_FOLDER      - Install path             (default: /usr/local/x-ui)

set -euo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# ─── Defaults ────────────────────────────────────────────────────────────────

XUI_FOLDER="${XUI_FOLDER:-/usr/local/x-ui}"
XUI_SERVICE="/etc/systemd/system"

XUI_SSL="${XUI_SSL:-ip}"
XUI_SSL_PORT="${XUI_SSL_PORT:-80}"
XUI_SSL_DOMAIN="${XUI_SSL_DOMAIN:-}"
XUI_SSL_IPV6="${XUI_SSL_IPV6:-}"
XUI_VERSION="${XUI_VERSION:-}"

# ─── Helpers ─────────────────────────────────────────────────────────────────

die()  { echo -e "${red}FATAL: ${plain}$*" >&2; exit 1; }
info() { echo -e "${green}$*${plain}"; }
warn() { echo -e "${yellow}$*${plain}"; }

gen_random() {
    openssl rand -base64 $(( $1 * 2 )) | tr -dc 'a-zA-Z0-9' | head -c "$1"
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|x64|amd64)       echo 'amd64' ;;
        i*86|x86)               echo '386' ;;
        armv8*|arm64|aarch64)   echo 'arm64' ;;
        armv7*|armv7|arm)       echo 'armv7' ;;
        armv6*)                 echo 'armv6' ;;
        armv5*)                 echo 'armv5' ;;
        s390x)                  echo 's390x' ;;
        *) die "Unsupported CPU architecture: $(uname -m)" ;;
    esac
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ -f /usr/lib/os-release ]]; then
        source /usr/lib/os-release
        echo "$ID"
    else
        die "Cannot detect OS"
    fi
}

detect_public_ip() {
    local urls=(
        "https://api4.ipify.org"
        "https://ipv4.icanhazip.com"
        "https://4.ident.me"
    )
    for url in "${urls[@]}"; do
        local ip
        ip=$(curl -s --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]') || continue
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done
    die "Could not detect public IP"
}

# ─── Checks ──────────────────────────────────────────────────────────────────

[[ $EUID -ne 0 ]] && die "Must run as root"

ARCH=$(detect_arch)
RELEASE=$(detect_os)
info "OS: ${RELEASE}  Arch: ${ARCH}"

# ─── Generate credentials if not provided ────────────────────────────────────

XUI_PORT="${XUI_PORT:-$(shuf -i 1024-62000 -n 1)}"
XUI_USERNAME="${XUI_USERNAME:-$(gen_random 10)}"
XUI_PASSWORD="${XUI_PASSWORD:-$(gen_random 10)}"
XUI_BASEPATH="${XUI_BASEPATH:-$(gen_random 18)}"

# ─── 1. Install base packages ────────────────────────────────────────────────

info "Installing base dependencies..."
export DEBIAN_FRONTEND=noninteractive
case "${RELEASE}" in
    ubuntu|debian|armbian)
        apt-get update -qq && apt-get install -y -q -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" cron curl tar tzdata socat ca-certificates openssl ;;
    fedora|amzn|rhel|almalinux|rocky|ol)
        dnf -y -q install cronie curl tar tzdata socat ca-certificates openssl ;;
    centos)
        if grep -q '^VERSION_ID="7' /etc/os-release 2>/dev/null; then
            yum -y install cronie curl tar tzdata socat ca-certificates openssl
        else
            dnf -y -q install cronie curl tar tzdata socat ca-certificates openssl
        fi ;;
    arch|manjaro|parch)
        pacman -Syu --noconfirm cronie curl tar tzdata socat ca-certificates openssl ;;
    alpine)
        apk update && apk add dcron curl tar tzdata socat ca-certificates openssl ;;
    *)
        apt-get update -qq && apt-get install -y -q -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" cron curl tar tzdata socat ca-certificates openssl ;;
esac

# ─── 2. Download 3x-ui ──────────────────────────────────────────────────────

if [[ -z "${XUI_VERSION}" ]]; then
    XUI_VERSION=$(curl -4Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "${XUI_VERSION}" ]] && die "Failed to fetch latest version from GitHub"
fi
info "Installing 3x-ui ${XUI_VERSION}..."

# Stop existing instance if upgrading
if [[ -d "${XUI_FOLDER}" ]]; then
    systemctl stop x-ui 2>/dev/null || rc-service x-ui stop 2>/dev/null || true
    rm -rf "${XUI_FOLDER}"
fi

cd "${XUI_FOLDER%/x-ui}/"
curl -4fLRo "x-ui-linux-${ARCH}.tar.gz" \
    "https://github.com/MHSanaei/3x-ui/releases/download/${XUI_VERSION}/x-ui-linux-${ARCH}.tar.gz" \
    || die "Download failed — check network / version tag"
tar zxf "x-ui-linux-${ARCH}.tar.gz"
rm -f "x-ui-linux-${ARCH}.tar.gz"

# ─── 3. Permissions ─────────────────────────────────────────────────────────

cd "${XUI_FOLDER}"
chmod +x x-ui x-ui.sh

if [[ "${ARCH}" =~ ^armv[567]$ ]]; then
    mv "bin/xray-linux-${ARCH}" bin/xray-linux-arm
    chmod +x bin/xray-linux-arm
else
    chmod +x "bin/xray-linux-${ARCH}"
fi

# ─── 4. Install CLI helper ──────────────────────────────────────────────────

curl -4fLRo /usr/bin/x-ui \
    https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
chmod +x /usr/bin/x-ui
mkdir -p /var/log/x-ui

# ─── 5. Install service ─────────────────────────────────────────────────────

if [[ "${RELEASE}" == "alpine" ]]; then
    curl -4fLRo /etc/init.d/x-ui \
        https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.rc
    chmod +x /etc/init.d/x-ui
    rc-update add x-ui
else
    local_service=""
    for suffix in "" ".debian" ".arch" ".rhel"; do
        if [[ -f "${XUI_FOLDER}/x-ui.service${suffix}" ]]; then
            local_service="${XUI_FOLDER}/x-ui.service${suffix}"
            break
        fi
    done

    if [[ -n "${local_service}" ]]; then
        cp -f "${local_service}" "${XUI_SERVICE}/x-ui.service"
    else
        # Pick distro-appropriate service from GitHub
        case "${RELEASE}" in
            ubuntu|debian|armbian)  svc_suffix=".debian" ;;
            arch|manjaro|parch)     svc_suffix=".arch" ;;
            *)                      svc_suffix=".rhel" ;;
        esac
        curl -4fLRo "${XUI_SERVICE}/x-ui.service" \
            "https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service${svc_suffix}"
    fi

    chown root:root "${XUI_SERVICE}/x-ui.service"
    chmod 644 "${XUI_SERVICE}/x-ui.service"
    systemctl daemon-reload
    systemctl enable x-ui
fi

# ─── 6. Configure panel (non-interactive) ───────────────────────────────────

info "Configuring panel..."
"${XUI_FOLDER}/x-ui" setting \
    -username "${XUI_USERNAME}" \
    -password "${XUI_PASSWORD}" \
    -port "${XUI_PORT}" \
    -webBasePath "${XUI_BASEPATH}"

"${XUI_FOLDER}/x-ui" migrate

# ─── 7. SSL ─────────────────────────────────────────────────────────────────

SERVER_IP=""

setup_acme() {
    export HOME=/root
    if ! [[ -f ~/.acme.sh/acme.sh ]]; then
        info "Installing acme.sh..."
        curl -fSL https://get.acme.sh 2>&1 | bash 2>&1
    fi
    if ! [[ -f ~/.acme.sh/acme.sh ]]; then
        warn "acme.sh install failed — skipping SSL"
        return 1
    fi
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force >/dev/null 2>&1
    return 0
}

install_ip_cert() {
    SERVER_IP=$(detect_public_ip)
    info "Setting up Let's Encrypt IP certificate for ${SERVER_IP}..."

    setup_acme || return 1

    local domain_args="-d ${SERVER_IP}"
    [[ -n "${XUI_SSL_IPV6}" ]] && domain_args="${domain_args} -d ${XUI_SSL_IPV6}"

    ~/.acme.sh/acme.sh --issue \
        ${domain_args} \
        --standalone \
        --server letsencrypt \
        --certificate-profile shortlived \
        --days 6 \
        --httpport "${XUI_SSL_PORT}" \
        --force || { warn "IP cert issuance failed — is port ${XUI_SSL_PORT} open?"; return 1; }

    local cert_dir="/root/cert/ip"
    mkdir -p "${cert_dir}"

    ~/.acme.sh/acme.sh --installcert -d "${SERVER_IP}" \
        --key-file "${cert_dir}/privkey.pem" \
        --fullchain-file "${cert_dir}/fullchain.pem" \
        --reloadcmd "systemctl restart x-ui 2>/dev/null || rc-service x-ui restart 2>/dev/null || true" \
        2>&1 || true

    if [[ -f "${cert_dir}/fullchain.pem" && -f "${cert_dir}/privkey.pem" ]]; then
        chmod 600 "${cert_dir}/privkey.pem"
        chmod 644 "${cert_dir}/fullchain.pem"
        "${XUI_FOLDER}/x-ui" cert -webCert "${cert_dir}/fullchain.pem" -webCertKey "${cert_dir}/privkey.pem"
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade >/dev/null 2>&1
        info "IP certificate installed successfully"
        return 0
    else
        warn "Certificate files not found after install"
        return 1
    fi
}

install_domain_cert() {
    [[ -z "${XUI_SSL_DOMAIN}" ]] && die "XUI_SSL=domain requires XUI_SSL_DOMAIN to be set"
    SERVER_IP="${XUI_SSL_DOMAIN}"
    info "Setting up Let's Encrypt certificate for ${XUI_SSL_DOMAIN}..."

    setup_acme || return 1

    local cert_dir="/root/cert/${XUI_SSL_DOMAIN}"
    mkdir -p "${cert_dir}"

    ~/.acme.sh/acme.sh --issue \
        -d "${XUI_SSL_DOMAIN}" \
        --listen-v6 --standalone \
        --httpport "${XUI_SSL_PORT}" \
        --force || { warn "Domain cert issuance failed"; return 1; }

    ~/.acme.sh/acme.sh --installcert -d "${XUI_SSL_DOMAIN}" \
        --key-file "${cert_dir}/privkey.pem" \
        --fullchain-file "${cert_dir}/fullchain.pem" \
        --reloadcmd "systemctl restart x-ui 2>/dev/null || rc-service x-ui restart 2>/dev/null || true" \
        2>&1 || true

    if [[ -f "${cert_dir}/fullchain.pem" && -f "${cert_dir}/privkey.pem" ]]; then
        chmod 600 "${cert_dir}/privkey.pem"
        chmod 644 "${cert_dir}/fullchain.pem"
        "${XUI_FOLDER}/x-ui" cert -webCert "${cert_dir}/fullchain.pem" -webCertKey "${cert_dir}/privkey.pem"
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade >/dev/null 2>&1
        info "Domain certificate installed successfully"
        return 0
    else
        warn "Certificate files not found after install"
        return 1
    fi
}

case "${XUI_SSL}" in
    ip)
        install_ip_cert || warn "SSL setup failed — panel will run without TLS" ;;
    domain)
        install_domain_cert || warn "SSL setup failed — panel will run without TLS" ;;
    skip)
        info "Skipping SSL setup (XUI_SSL=skip)" ;;
    *)
        warn "Unknown XUI_SSL value '${XUI_SSL}', skipping SSL" ;;
esac

# ─── 8. Start ───────────────────────────────────────────────────────────────

if [[ "${RELEASE}" == "alpine" ]]; then
    rc-service x-ui start
else
    systemctl start x-ui
fi

# ─── 9. Persist credentials ─────────────────────────────────────────────────

CRED_FILE="/root/.3xui-credentials"
cat > "${CRED_FILE}" <<EOF
XUI_USERNAME=${XUI_USERNAME}
XUI_PASSWORD=${XUI_PASSWORD}
XUI_PORT=${XUI_PORT}
XUI_BASEPATH=${XUI_BASEPATH}
XUI_VERSION=${XUI_VERSION}
EOF
chmod 600 "${CRED_FILE}"

# ─── 10. Summary ────────────────────────────────────────────────────────────

[[ -z "${SERVER_IP}" ]] && SERVER_IP=$(detect_public_ip 2>/dev/null || echo "<server-ip>")

PROTO="http"
[[ "${XUI_SSL}" != "skip" ]] && PROTO="https"

echo ""
echo "==========================================="
echo " 3x-ui ${XUI_VERSION} installed"
echo "==========================================="
echo " Username:    ${XUI_USERNAME}"
echo " Password:    ${XUI_PASSWORD}"
echo " Port:        ${XUI_PORT}"
echo " WebBasePath: ${XUI_BASEPATH}"
echo " Access URL:  ${PROTO}://${SERVER_IP}:${XUI_PORT}/${XUI_BASEPATH}"
echo ""
echo " Credentials saved to: ${CRED_FILE}"
echo "==========================================="
