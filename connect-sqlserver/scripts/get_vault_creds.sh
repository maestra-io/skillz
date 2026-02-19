#!/bin/bash
# Get database credentials from Vault (env-aware, dual-path fallback)
# Usage: ./get_vault_creds.sh <db-name> [role]
# Role: reader (default), writer, owner
# Requires: VAULT_ADDR (from resolve_env.sh)
# Tries cdp-database/creds/... first, falls back to database/creds/...

set -e

if [ -z "$1" ]; then
	echo "Error: Database name required" >&2
	echo "Usage: $0 <db-name> [reader|writer|owner]" >&2
	exit 1
fi

DB_NAME="$1"
ROLE="${2:-reader}"

if ! command -v jq > /dev/null 2>&1; then
	echo "Error: jq is required" >&2
	exit 1
fi

# Check Vault authentication
if ! VAULT_ADDR="$VAULT_ADDR" vault token lookup > /dev/null 2>&1; then
	echo "Error: Not authenticated to Vault ($VAULT_ADDR)" >&2
	echo "Please run: VAULT_ADDR=$VAULT_ADDR vault login -method=oidc" >&2
	exit 1
fi

# Remove db- prefix if present
DB_NAME_CLEAN="${DB_NAME#db-}"

# Remove teleport domain suffix if present
DB_NAME_CLEAN="${DB_NAME_CLEAN%.teleport.maestra.io}"
DB_NAME_CLEAN="${DB_NAME_CLEAN%.corp.itcd.ru}"

# Try cdp-database first, then database
CREDS=""
USED_PATH=""
for PREFIX in cdp-database database; do
	VAULT_PATH="$PREFIX/creds/db-${ROLE}-${DB_NAME_CLEAN}"
	CREDS=$(VAULT_ADDR="$VAULT_ADDR" vault read -format=json "$VAULT_PATH" 2>/dev/null) && USED_PATH="$VAULT_PATH" && break
	CREDS=""
done

if [ -z "$CREDS" ]; then
	echo "Error: Failed to retrieve credentials from Vault" >&2
	echo "Tried paths:" >&2
	echo "  cdp-database/creds/db-${ROLE}-${DB_NAME_CLEAN}" >&2
	echo "  database/creds/db-${ROLE}-${DB_NAME_CLEAN}" >&2
	echo "" >&2
	echo "Available roles: reader, writer, owner" >&2
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
