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

# Replace AWS Applications environment variables
content="${content//\$\{AWS_START_URL\}/${AWS_START_URL}}"
content="${content//\$\{AWS_WORKMAIL_URL\}/${AWS_WORKMAIL_URL}}"

# Replace SMTP environment variables
content="${content//\$\{SMTP_HOST\}/${SMTP_HOST}}"
content="${content//\$\{SMTP_PORT\}/${SMTP_PORT}}"
content="${content//\$\{SMTP_FROM\}/${SMTP_FROM}}"
content="${content//\$\{SMTP_FROM_DISPLAY_NAME\}/${SMTP_FROM_DISPLAY_NAME}}"
content="${content//\$\{SMTP_USER\}/${SMTP_USER}}"
content="${content//\$\{SMTP_PASSWORD\}/${SMTP_PASSWORD}}"
content="${content//\$\{SMTP_SSL\}/${SMTP_SSL}}"
content="${content//\$\{SMTP_STARTTLS\}/${SMTP_STARTTLS}}"

# Write processed content to output file
echo "$content" >"$output_file"

# Start Keycloak with realm import (overwrite existing)
exec /opt/keycloak/bin/kc.sh start --import-realm --spi-import-strategy=overwrite-existing
