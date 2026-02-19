#!/bin/bash
# Get database credentials from Vault (env-aware, dual-path fallback)
# Usage: ./vault_creds.sh [--raw] <env> <db-name> [reader|writer|owner]
# Default: copies credentials to clipboard via pbcopy
# --raw:   outputs USERNAME\nPASSWORD to stdout (for scripting)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_vault_common.sh"

# Parse --raw flag
RAW_MODE=false
ARGS=()
for arg in "$@"; do
	if [ "$arg" = "--raw" ]; then
		RAW_MODE=true
	else
		ARGS+=("$arg")
	fi
done

if [ -z "${ARGS[0]}" ] || [ -z "${ARGS[1]}" ]; then
	echo "Error: Environment and database name required" >&2
	echo "Usage: $0 [--raw] <env> <db-name> [reader|writer|owner]" >&2
	echo "Example: $0 maestra test-maestra" >&2
	exit 1
fi

ENV_NAME="${ARGS[0]}"
DB_NAME="${ARGS[1]}"
ROLE="${ARGS[2]:-reader}"

case "$ROLE" in
	reader|writer|owner) ;;
	*)
		echo "Error: Invalid role '$ROLE'. Must be reader, writer, or owner." >&2
		exit 1
		;;
esac

vault_require_jq
vault_init "$ENV_NAME"

DB_NAME_CLEAN=$(vault_clean_db_name "$DB_NAME")

_creds_path() { echo "$1/creds/db-${ROLE}-$2"; }
vault_resolve_path "$ENV_NAME" "$DB_NAME_CLEAN" _creds_path

# Extract username and password
USERNAME=$(echo "$VAULT_RESULT" | jq -r '.data.username')
PASSWORD=$(echo "$VAULT_RESULT" | jq -r '.data.password')

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ "$USERNAME" = "null" ] || [ "$PASSWORD" = "null" ]; then
	echo "Error: Could not extract credentials from Vault response" >&2
	exit 1
fi

if [ "$RAW_MODE" = true ]; then
	printf '%s\n%s\n' "$USERNAME" "$PASSWORD"
else
	printf "Username: %s\nPassword: %s" "$USERNAME" "$PASSWORD" | pbcopy
	echo "Credentials copied to clipboard (role: $ROLE, expires in 12h)" >&2
fi
