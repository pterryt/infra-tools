#!/usr/bin/env bash
# Initializes nginx.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_debian_family

install_packages nginx gettext-base

log_info "Installing shared security headers..."
mkdir -p /etc/nginx/snippets
cp "$SCRIPT_DIR/security-headers.conf" \
   /etc/nginx/snippets/security-headers.conf

log_info "Installing TLS parameters..."
cp "$SCRIPT_DIR/templates/ssl-params.conf" \
   /etc/nginx/ssl-params.conf

if [[ -e /etc/nginx/sites-enabled/default ]]; then
    rm -f /etc/nginx/sites-enabled/default
    log_ok "Disabled default nginx site."
fi

NGINX_CONF=/etc/nginx/nginx.conf

if ! grep -q "server_tokens off" "$NGINX_CONF"; then
    sed -i '/http {/a \\tserver_tokens off;' "$NGINX_CONF"
fi

nginx -t

systemctl enable --now nginx >/dev/null
systemctl reload nginx

log_ok "nginx initialized."
