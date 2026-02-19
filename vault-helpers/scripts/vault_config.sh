#!/bin/bash
# Get database connection config from Vault (host, database name, driver)
# Usage: ./vault_config.sh <env> <db-name>
# Outputs: host database driver (space-separated)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Error: Environment and database name required" >&2
	echo "Usage: $0 <env> <db-name>" >&2
	exit 1
fi

ENV_NAME="$1"
DB_NAME="$2"

# Remove db- prefix if present
DB_NAME_CLEAN="${DB_NAME#db-}"

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

# Try cdp-database first, then database
CONFIG=""
for PREFIX in cdp-database database; do
	VAULT_PATH="$PREFIX/config/db-$DB_NAME_CLEAN"
	CONFIG=$(vault read -format=json "$VAULT_PATH" 2>/dev/null) && break
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
