#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ddns.env"

ZONE_NAME="${CLOUDFLARE_ZONE_NAME}"
RECORD_NAME="${CLOUDFLARE_RECORD_NAME}"

: "${TOKEN:?TOKEN must be set}"

API="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer ${TOKEN}"

echo "Looking up zone: ${ZONE_NAME}"

ZONE_RESPONSE="$(
    curl --fail-with-body --silent --show-error \
        "${API}/zones?name=${ZONE_NAME}" \
        -H "${AUTH_HEADER}" \
        -H "Content-Type: application/json"
)"

echo
echo "Zone response:"
printf '%s\n' "$ZONE_RESPONSE"

ZONE_ID="$(
    printf '%s' "$ZONE_RESPONSE" |
        jq -r '.result[0].id // empty'
)"

if [[ -z "$ZONE_ID" ]]; then
    echo "ERROR: Could not find zone ID for ${ZONE_NAME}" >&2
    exit 1
fi

echo
echo "ZONE_ID=${ZONE_ID}"
echo
echo "Looking up DNS record: ${RECORD_NAME}"

# URL-encode the wildcard (*) in the record name.
ENCODED_RECORD_NAME="${RECORD_NAME//\*/%2A}"

RECORD_RESPONSE="$(
    curl --fail-with-body --silent --show-error \
        "${API}/zones/${ZONE_ID}/dns_records?type=A&name=${ENCODED_RECORD_NAME}" \
        -H "${AUTH_HEADER}" \
        -H "Content-Type: application/json"
)"

echo
echo "DNS record response:"
printf '%s\n' "$RECORD_RESPONSE"

RECORD_ID="$(
    printf '%s' "$RECORD_RESPONSE" |
        jq -r '.result[0].id // empty'
)"

if [[ -z "$RECORD_ID" ]]; then
    echo "ERROR: Could not find DNS record ${RECORD_NAME}" >&2
    exit 1
fi

echo
echo "========================================"
echo "Values for your DDNS configuration:"
echo "========================================"
echo "ZONE_ID=${ZONE_ID}"
echo "RECORD_ID=${RECORD_ID}"
echo "DOMAIN=${RECORD_NAME}"
echo
echo "TOKEN=<keep your existing token>"