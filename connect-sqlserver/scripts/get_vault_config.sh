#!/bin/bash
# Get database connection config from Vault (host, database name, driver)
# Usage: ./get_vault_config.sh <db-name>
# Requires: VAULT_ADDR (from resolve_env.sh)
# Tries cdp-database/config/db-{name} first, falls back to database/config/db-{name}

set -e

if [ -z "$1" ]; then
	echo "Error: Database name required" >&2
	echo "Usage: $0 <db-name>" >&2
	exit 1
fi

DB_NAME="$1"

# Remove db- prefix if present
DB_NAME_CLEAN="${DB_NAME#db-}"

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

# Try cdp-database first, then database
CONFIG=""
for PREFIX in cdp-database database; do
	VAULT_PATH="$PREFIX/config/db-$DB_NAME_CLEAN"
	CONFIG=$(VAULT_ADDR="$VAULT_ADDR" vault read -format=json "$VAULT_PATH" 2>/dev/null) && break
	CONFIG=""
done

if [ -z "$CONFIG" ]; then
	echo "Error: Failed to read connection config from Vault" >&2
	echo "Tried paths:" >&2
	echo "  cdp-database/config/db-$DB_NAME_CLEAN" >&2
	echo "  database/config/db-$DB_NAME_CLEAN" >&2
	exit 1
fi

# Extract connection_url from the nested connection_details
# Format: sqlserver://{{username}}:{{password}}@HOST?database=DATABASE
CONN_URL=$(echo "$CONFIG" | jq -r '.data.connection_details.connection_url // .data.connection_url // empty')

if [ -z "$CONN_URL" ]; then
	echo "Error: No connection_url found in Vault config" >&2
	exit 1
fi

# Parse host: everything between @ and ? (or end of string)
HOST=$(echo "$CONN_URL" | sed 's|.*@||' | sed 's|?.*||' | sed 's|/.*||')

# Parse database name from query parameter
DATABASE=$(echo "$CONN_URL" | grep -o 'database=[^&]*' | sed 's/database=//' || echo "")

# Parse driver (protocol prefix before ://)
DRIVER=$(echo "$CONN_URL" | sed 's|://.*||')

if [ -z "$HOST" ]; then
	echo "Error: Could not parse host from connection_url: $CONN_URL" >&2
	exit 1
fi

# Output space-separated: host database driver
echo "$HOST $DATABASE $DRIVER"
