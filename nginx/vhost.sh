#!/usr/bin/env bash
# vhost.sh — manage nginx reverse proxy vhosts
#
# Usage:
#   ./vhost.sh add env/services.d/myapp.env
#   ./vhost.sh remove myapp
#
# create:
#   - renders nginx vhost
#   - enables site
#   - validates nginx configuration
#   - reloads nginx
#
# remove:
#   - disables nginx site
#   - removes nginx configuration
#   - validates nginx configuration
#   - reloads nginx

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<EOF
Usage:
  $0 add <path-to-service.env>
  $0 remove <service-name>

Examples:
  $0 add env/services.d/jellyfin.env
  $0 remove jellyfin
EOF
    exit 1
}

[[ $# -ge 2 ]] || usage

ACTION="$1"
TARGET="$2"

require_root
require_debian_family
require_cmd nginx


create_service() {
    local ENV_FILE="$1"

    require_cmd envsubst

    log_info "Loading ${ENV_FILE}..."
    load_service_env "$ENV_FILE"

    validate_required_vars \
        SERVICE_NAME \
        DOMAIN \
        UPSTREAM_PORT \
        BASE_DOMAIN

    validate_safe_token "SERVICE_NAME" "$SERVICE_NAME"
    validate_safe_token "DOMAIN" "$DOMAIN"
    validate_safe_token "BASE_DOMAIN" "$BASE_DOMAIN"

    UPSTREAM_HOST="${UPSTREAM_HOST:-127.0.0.1}"
    CLIENT_MAX_BODY_SIZE="${CLIENT_MAX_BODY_SIZE:-10m}"

    # envsubst runs as a separate process and only sees the environment —
    # any default computed here (as opposed to coming straight from the
    # sourced env file under load_service_env's `set -a`) must be exported
    # explicitly, or it renders as an empty string.
    export UPSTREAM_HOST CLIENT_MAX_BODY_SIZE BASE_DOMAIN

    log_info "Service:     ${SERVICE_NAME}"
    log_info "Domain:      ${DOMAIN}"
    log_info "Base domain: ${BASE_DOMAIN}"
    log_info "Upstream:    ${UPSTREAM_HOST}:${UPSTREAM_PORT}"

    local VHOST_PATH="/etc/nginx/sites-available/${SERVICE_NAME}.conf"
    local CERT_PATH="/etc/letsencrypt/live/${BASE_DOMAIN}/fullchain.pem"

    if [[ -f "$CERT_PATH" ]]; then
        log_info "Found wildcard cert for ${BASE_DOMAIN}, rendering HTTPS vhost..."
        render_template \
            "$SCRIPT_DIR/templates/nginx-vhost-ssl.conf.tmpl" \
            "$VHOST_PATH" \
            SERVICE_NAME \
            DOMAIN \
            BASE_DOMAIN \
            UPSTREAM_HOST \
            UPSTREAM_PORT \
            CLIENT_MAX_BODY_SIZE
    else
        log_warn "No wildcard cert found at ${CERT_PATH} — rendering HTTP-only vhost."
        log_warn "Run ./request-wildcard-cert.sh, then re-run '$0 add ${ENV_FILE}' to upgrade this vhost to HTTPS."
        render_template \
            "$SCRIPT_DIR/templates/nginx-vhost.conf.tmpl" \
            "$VHOST_PATH" \
            SERVICE_NAME \
            DOMAIN \
            UPSTREAM_HOST \
            UPSTREAM_PORT \
            CLIENT_MAX_BODY_SIZE
    fi

    ln -sf \
        "$VHOST_PATH" \
        "/etc/nginx/sites-enabled/${SERVICE_NAME}.conf"

    log_info "Validating nginx configuration..."
    nginx -t

    systemctl reload nginx

    log_ok "Enabled nginx vhost '${SERVICE_NAME}'."
    log_ok "Reverse proxy configured for ${DOMAIN}"
}


remove_service() {
    local SERVICE_NAME="$1"

    validate_safe_token "SERVICE_NAME" "$SERVICE_NAME"

    local VHOST_PATH="/etc/nginx/sites-available/${SERVICE_NAME}.conf"
    local VHOST_LINK="/etc/nginx/sites-enabled/${SERVICE_NAME}.conf"

    log_info "Removing nginx vhost '${SERVICE_NAME}'..."

    local removed=false

    if [[ -e "$VHOST_LINK" || -L "$VHOST_LINK" ]]; then
        rm -f "$VHOST_LINK"
        log_ok "Removed nginx enabled site."
        removed=true
    fi

    if [[ -e "$VHOST_PATH" ]]; then
        rm -f "$VHOST_PATH"
        log_ok "Removed nginx configuration."
        removed=true
    fi

    if [[ "$removed" == true ]]; then
        nginx -t
        systemctl reload nginx
        log_ok "nginx reloaded."
    else
        log_warn "No nginx vhost found for '${SERVICE_NAME}'."
    fi

    log_ok "Done."
}


case "$ACTION" in
    add)
        create_service "$TARGET"
        ;;

    remove)
        remove_service "$TARGET"
        ;;

    *)
        usage
        ;;
esac