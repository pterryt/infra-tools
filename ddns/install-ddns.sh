#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="ddns.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing DDNS updater..."

#Install env
sudo install -m 600 \
    "$SCRIPT_DIR/ddns.env" \
    "/etc/ddns.env"

# Install update script
sudo install -m 755 \
    "$SCRIPT_DIR/ddns.sh" \
    "/usr/local/bin/$SCRIPT_NAME"

# Install systemd units
sudo install -m 644 \
    "$SCRIPT_DIR/ddns.service" \
    "/etc/systemd/system/ddns.service"

sudo install -m 644 \
    "$SCRIPT_DIR/ddns.timer" \
    "/etc/systemd/system/ddns.timer"

# Reload systemd
sudo systemctl daemon-reload

# Enable and start timer
sudo systemctl enable --now ddns.timer

echo
echo "DDNS timer installed."
echo
systemctl status ddns.timer --no-pager