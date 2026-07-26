#!/usr/bin/env bash
set -euo pipefail
source "$SCRIPT_DIR/common.sh"

require_root

# TODO: utilize or remove apt-listchanges
install_packages unattended-upgrades apt-listchanges

log_info "Enabling automatic security updates..."
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

log_info "Enabling unattended-upgrades service..."
systemctl enable --now unattended-upgrades.service >/dev/null 2>&1 || true

log_info "Configuration complete."

echo
echo "Current status:"
apt-config dump | grep 'APT::Periodic::'
