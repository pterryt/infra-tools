#!/usr/bin/env bash
# request-wildcard-cert.sh — obtain or renew a wildcard Let's Encrypt
# certificate using Cloudflare DNS validation.
#
# Usage:
#   ./request-wildcard-cert.sh config.env
#
# Required config variables:
#   BASE_DOMAIN
#   CERTBOT_EMAIL
#   CLOUDFLARE_API_TOKEN
#
# Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: $0 <config.env>"
  exit 1
}

[[ $# -eq 1 ]] || usage

CONFIG="$1"

require_root
require_debian_family
require_cmd certbot


load_service_env "$CONFIG"

validate_required_vars \
  BASE_DOMAIN \
  CERTBOT_EMAIL \
  CLOUDFLARE_API_TOKEN

SECRETS_DIR="/root/.secrets"
CF_CREDS="${SECRETS_DIR}/cloudflare.ini"


log_info "Updating package index..."
apt-get update -qq

log_info "Installing certbot..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  certbot \
  python3-certbot-nginx \
  python3-certbot-dns-cloudflare


mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

cat > "$CF_CREDS" <<EOF
dns_cloudflare_api_token=${CLOUDFLARE_API_TOKEN}
EOF

chmod 600 "$CF_CREDS"

log_info "Requesting wildcard certificate for ${BASE_DOMAIN}..."

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials "$CF_CREDS" \
  --dns-cloudflare-propagation-seconds 30 \
  --agree-tos \
  --non-interactive \
  --email "$CERTBOT_EMAIL" \
  --keep-until-expiring \
  --deploy-hook "systemctl reload nginx" \
  -d "$BASE_DOMAIN" \
  -d "*.${BASE_DOMAIN}"

log_ok "Certificate ready."

echo
log_info "Certificate location:"
echo "  /etc/letsencrypt/live/${BASE_DOMAIN}/"
echo
log_info "Configure nginx vhosts to use:"
echo "  ssl_certificate     /etc/letsencrypt/live/${BASE_DOMAIN}/fullchain.pem;"
echo "  ssl_certificate_key /etc/letsencrypt/live/${BASE_DOMAIN}/privkey.pem;"
