#!/usr/bin/env bash
# Initializes fail2ban.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_debian_family

install_packages fail2ban

log_info "Installing fail2ban configuration..."

mkdir -p /etc/fail2ban/jail.d

cat >/etc/fail2ban/jail.d/nginx-deploy.local <<'EOF'
[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true
EOF

systemctl enable --now fail2ban >/dev/null
systemctl restart fail2ban

log_ok "fail2ban configured."