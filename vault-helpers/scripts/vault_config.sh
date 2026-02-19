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
chmod 700 "$HOME/.vault-tokens" 2>/dev/null || true
TOKEN_FILE="$HOME/.vault-tokens/$ENV_NAME"
if [ -f "$TOKEN_FILE" ]; then
	VAULT_TOKEN=$(cat "$TOKEN_FILE")
	export VAULT_TOKEN
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

# Environment-specific suffixes for platform databases
case "$ENV_NAME" in
	staging) ENV_SUFFIXES=("-staging") ;;
	prod)    ENV_SUFFIXES=("-stable" "-beta") ;;
	sigma)   ENV_SUFFIXES=("-sigma") ;;
	maestra) ENV_SUFFIXES=("-omega" "-stable") ;;
	*)       ENV_SUFFIXES=() ;;
esac

# Try exact name first, then with env suffixes appended
TRIED_PATHS=()
CONFIG=""
for NAME_VARIANT in "$DB_NAME_CLEAN" "${ENV_SUFFIXES[@]/#/$DB_NAME_CLEAN}"; do
	for PREFIX in cdp-database database; do
		VAULT_PATH="$PREFIX/config/db-$NAME_VARIANT"
		TRIED_PATHS+=("$VAULT_PATH")
		CONFIG=$(vault read -format=json "$VAULT_PATH" 2>/dev/null) && break 2
		CONFIG=""
	done
done

# Fallback: fuzzy search via vault list
if [ -z "$CONFIG" ]; then
	echo "Exact match not found, searching..." >&2
	MATCHES=()
	for PREFIX in cdp-database database; do
		LIST=$(vault list -format=json "$PREFIX/config" 2>/dev/null) || continue
		while IFS= read -r entry; do
			[ -n "$entry" ] && MATCHES+=("$PREFIX/config/$entry")
		done < <(echo "$LIST" | jq -r '.[]' | python3 -c "
import sys
terms = sys.argv[1].lower().split('-')
for line in sys.stdin:
    e = line.strip().lower()
    if all(t in e for t in terms):
        print(line.strip())
" "$DB_NAME_CLEAN")
	done

	if [ "${#MATCHES[@]}" -eq 1 ]; then
		VAULT_PATH="${MATCHES[0]}"
		echo "Found: $VAULT_PATH" >&2
		CONFIG=$(vault read -format=json "$VAULT_PATH" 2>/dev/null)
	elif [ "${#MATCHES[@]}" -gt 1 ]; then
		echo "Error: Multiple matches found for '$DB_NAME_CLEAN':" >&2
		for m in "${MATCHES[@]}"; do echo "  $m" >&2; done
		echo "Please specify the exact name." >&2
		exit 1
	fi
fi

if [ -z "$CONFIG" ]; then
	echo "Error: Failed to read connection config from Vault" >&2
	echo "Tried paths:" >&2
	for p in "${TRIED_PATHS[@]}"; do echo "  $p" >&2; done
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
	echo "Error: Could not parse host from connection_url" >&2
	exit 1
fi

# Output space-separated: host database driver
echo "$HOST $DATABASE $DRIVER"
