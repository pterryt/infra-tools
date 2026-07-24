#!/usr/bin/env bash
set -euo pipefail
: "${SERVICE_NAME:?Missing environment variables. Run via Make. Use 'make help' for options.}"

REQUIRED_COMMANDS=(
    id
    useradd
    passwd
    install
    loginctl
    sudo
    machinectl
)

missing_commands=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_commands+=("$cmd")
    fi
done

HOME_DIR="/home/${SERVICE_USER}"
LOGIN_SHELL="/usr/sbin/nologin"

if ! id "$SERVICE_USER" &>/dev/null; then
  echo "Creating service account '${SERVICE_USER}'..."
    sudo useradd \
        --create-home \
        --home-dir "${HOME_DIR}" \
        --shell "${LOGIN_SHELL}" \
        --user-group \
        --comment "Rootless Podman Service Account" \
        "${SERVICE_USER}"
  # Prevent password logins.
    sudo passwd -l "${SERVICE_USER}" >/dev/null
else
    echo "User already exists. Continuing"
fi

SERVICE_UID=$(id -u "${SERVICE_USER}")
SERVICE_GID=$(id -g "${SERVICE_USER}")

echo "Created ${SERVICE_USER}: UID=${SERVICE_UID} GID=${SERVICE_GID}"

echo "Creating directory structure..."
sudo install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" -m 700 \
    "${HOME_DIR}/.config/containers" \
    "${HOME_DIR}/.config/containers/systemd" \

echo "Enabling systemd lingering..."
sudo loginctl enable-linger "${SERVICE_USER}"


echo
echo "Successfully created service account."
echo
echo "  Service : ${SERVICE_NAME}"
echo "  User    : ${SERVICE_USER}"
echo "  Home    : ${HOME_DIR}"
