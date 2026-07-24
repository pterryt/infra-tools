#!/usr/bin/env bash
# Initializes UFW firewall.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_debian_family

install_packages ufw

log_info "Configuring firewall..."

ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null

ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

if ! ufw status | grep -q "Status: active"; then
    ufw --force enable >/dev/null
fi

log_ok "Firewall active."