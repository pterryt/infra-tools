#!/usr/bin/env bash
# setup-nginx.sh — one-time server bootstrap for nginx-deploy
#
# Installs and configures:
#   - nginx
#   - certbot (Let's Encrypt, nginx plugin)
#   - ufw (firewall: allow SSH + HTTP/HTTPS only)
#   - fail2ban (brute-force protection, incl. an nginx jail)
#   - gettext-base (envsubst, used for config templating)
#
# Safe to re-run.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/common.sh"

require_root
require_debian_family

log_info "Updating package index..."
apt-get update -qq

log_info "Installing nginx, ufw, fail2ban, gettext-base..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  nginx \
  ufw \
  fail2ban \
  gettext-base

# --- firewall -------------------------------------------------------------
log_info "Configuring ufw (allow SSH, HTTP, HTTPS; default deny incoming)..."
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
if ! ufw status | grep -q "Status: active"; then
  ufw --force enable >/dev/null
fi
log_ok "Firewall active: SSH + HTTP/HTTPS allowed, everything else denied inbound."

# --- fail2ban ---------------------------------------------------------------
log_info "Configuring fail2ban jail for nginx..."
cat > /etc/fail2ban/jail.d/nginx-deploy.local <<'EOF'
[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true
EOF
systemctl enable --now fail2ban >/dev/null
systemctl restart fail2ban
log_ok "fail2ban enabled (sshd, nginx-http-auth, nginx-botsearch jails)."

# --- nginx base hardening ----------------------------------------------------
log_info "Installing shared security-headers snippet..."
mkdir -p /etc/nginx/snippets
cp "$SCRIPT_DIR/security-headers.conf" /etc/nginx/snippets/security-headers.conf

log_info "Installing shared TLS params snippet..."
cp "$SCRIPT_DIR/templates/ssl-params.conf" /etc/nginx/ssl-params.conf

# Disable the default site so it doesn't catch unmatched Host headers /
# accidental domains pointed at this server.
if [[ -e /etc/nginx/sites-enabled/default ]]; then
  rm -f /etc/nginx/sites-enabled/default
  log_ok "Disabled default nginx site."
fi

# A couple of safe, conservative defaults in nginx.conf if not already set.
NGINX_CONF=/etc/nginx/nginx.conf
if ! grep -q "server_tokens off" "$NGINX_CONF"; then
  sed -i '/http {/a \\tserver_tokens off;' "$NGINX_CONF"
fi

nginx -t
systemctl enable --now nginx >/dev/null
systemctl reload nginx

log_ok "Base server setup complete."
echo
log_info "Next: copy env/services.d/example.env to env/services.d/<yourservice>
.env, edit it,"
log_info "then run:  ./vhost.sh add env/services.d/<yourservice>.env"
