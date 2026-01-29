#!/bin/bash
# Get database credentials from Vault
# Usage: ./get_vault_creds.sh <db-name> [role]
# Role: reader (default), writer, owner

set -e

if [ -z "$1" ]; then
    echo "Error: Database name required" >&2
    echo "Usage: $0 <db-name> [reader|writer|owner]" >&2
    exit 1
fi

DB_NAME="$1"
ROLE="${2:-reader}"

# Set Vault address if not already set
export VAULT_ADDR="${VAULT_ADDR:-https://vault.maestra.io}"

# Check Vault authentication
if ! vault token lookup > /dev/null 2>&1; then
    echo "Error: Not authenticated to Vault" >&2
    echo "Please run: vault login -method=oidc" >&2
    exit 1
fi

# Remove db- prefix if present for vault path
DB_NAME_CLEAN="${DB_NAME#db-}"

# Remove .teleport.maestra.io suffix if present
DB_NAME_CLEAN="${DB_NAME_CLEAN%.teleport.maestra.io}"

# Construct Vault path
VAULT_PATH="database/creds/db-${ROLE}-${DB_NAME_CLEAN}"

# Get credentials from Vault
CREDS=$(vault read -format=json "$VAULT_PATH" 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve credentials from Vault" >&2
    echo "Path: $VAULT_PATH" >&2
    echo "Response: $CREDS" >&2
    echo "" >&2
    echo "Available roles: reader, writer, owner" >&2
    echo "Check Vault authentication: vault token lookup" >&2
    echo "Try different role or verify path exists" >&2
    exit 1
fi

# Extract username and password
USERNAME=$(echo "$CREDS" | jq -r '.data.username')
PASSWORD=$(echo "$CREDS" | jq -r '.data.password')

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ "$USERNAME" = "null" ] || [ "$PASSWORD" = "null" ]; then
    echo "Error: Could not extract credentials from Vault response" >&2
    exit 1
fi

# Output space-separated for easy parsing
echo "$USERNAME $PASSWORD"
