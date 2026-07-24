#!/usr/bin/env bash
set -euo pipefail

IP=$(curl -s https://api.ipify.org)

curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\": \"A\",
    \"name\": \"$DOMAIN\",
    \"content\": \"$IP\",
    \"ttl\": 120,
    \"proxied\": false
  }"
