#!/bin/bash
# Get database credentials from Vault (env-aware, dual-path fallback)
# Usage: ./vault_creds.sh <env> <db-name> [reader|writer|owner]
# Copies credentials to clipboard via pbcopy

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Error: Environment and database name required" >&2
	echo "Usage: $0 <env> <db-name> [reader|writer|owner]" >&2
	echo "Example: $0 maestra test-maestra" >&2
	exit 1
fi

ENV_NAME="$1"
DB_NAME="$2"
ROLE="${3:-reader}"

if ! command -v jq > /dev/null 2>&1; then
	echo "Error: jq is required" >&2
	exit 1
fi

# Resolve environment
eval "$("$SCRIPT_DIR/resolve_env.sh" "$ENV_NAME")"

# Load per-env token
TOKEN_FILE="$HOME/.vault-tokens/$ENV_NAME"
if [ -f "$TOKEN_FILE" ]; then
	export VAULT_TOKEN=$(cat "$TOKEN_FILE")
else
	echo "Error: No cached token for $ENV_NAME (run: vault_login.sh $ENV_NAME)" >&2
	exit 1
fi

# Check Vault authentication
if ! vault token lookup > /dev/null 2>&1; then
	echo "Error: Not authenticated to Vault ($VAULT_ADDR)" >&2
	echo "Run: $SCRIPT_DIR/vault_login.sh $ENV_NAME" >&2
	exit 1
fi

# Remove db- prefix if present
DB_NAME_CLEAN="${DB_NAME#db-}"

# Remove teleport domain suffix if present
DB_NAME_CLEAN="${DB_NAME_CLEAN%.teleport.maestra.io}"
DB_NAME_CLEAN="${DB_NAME_CLEAN%.corp.itcd.ru}"

# Try cdp-database first, then database
CREDS=""
for PREFIX in cdp-database database; do
	VAULT_PATH="$PREFIX/creds/db-${ROLE}-${DB_NAME_CLEAN}"
	CREDS=$(vault read -format=json "$VAULT_PATH" 2>/dev/null) && break
	CREDS=""
done

if [ -z "$CREDS" ]; then
	echo "Error: Failed to retrieve credentials from Vault" >&2
	echo "Tried paths:" >&2
	echo "  cdp-database/creds/db-${ROLE}-${DB_NAME_CLEAN}" >&2
	echo "  database/creds/db-${ROLE}-${DB_NAME_CLEAN}" >&2
	exit 1
fi

# Extract username and password
USERNAME=$(echo "$CREDS" | jq -r '.data.username')
PASSWORD=$(echo "$CREDS" | jq -r '.data.password')

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ "$USERNAME" = "null" ] || [ "$PASSWORD" = "null" ]; then
	echo "Error: Could not extract credentials from Vault response" >&2
	exit 1
fi

# Copy to clipboard
printf "Username: %s\nPassword: %s" "$USERNAME" "$PASSWORD" | pbcopy
echo "Credentials copied to clipboard (role: $ROLE, expires in 12h)" >&2

