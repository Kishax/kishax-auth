#!/bin/bash

# Process template with bash variable substitution
template_file="/opt/keycloak/data/import/realm-export.json.template"
output_file="/opt/keycloak/data/import/realm-export.json"

# Read template and substitute variables using bash
content=$(cat "$template_file")

# Replace environment variables
content="${content//\$\{GITHUB_CLIENT_ID\}/${GITHUB_CLIENT_ID}}"
content="${content//\$\{GITHUB_CLIENT_SECRET\}/${GITHUB_CLIENT_SECRET}}"
content="${content//\$\{IAM_IDENTITY_CENTER_ACS_URL\}/${IAM_IDENTITY_CENTER_ACS_URL}}"
content="${content//\$\{IAM_IDENTITY_CENTER_ISSUER_URL\}/${IAM_IDENTITY_CENTER_ISSUER_URL}}"

# Write processed content to output file
echo "$content" >"$output_file"

# Start Keycloak with realm import (overwrite existing)
exec /opt/keycloak/bin/kc.sh start --import-realm --spi-import-strategy=overwrite-existing

