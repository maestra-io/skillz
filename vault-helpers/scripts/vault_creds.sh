#!/bin/bash
# Get database credentials from Vault (env-aware, dual-path fallback)
# Usage: ./vault_creds.sh [--raw] <env> <db-name> [reader|writer|owner]
# Default: copies credentials to clipboard via pbcopy
# --raw:   outputs USERNAME\nPASSWORD to stdout (for scripting)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Remove db- prefix if present
DB_NAME_CLEAN="${DB_NAME#db-}"

# Remove teleport domain suffix if present
DB_NAME_CLEAN="${DB_NAME_CLEAN%.teleport.maestra.io}"
DB_NAME_CLEAN="${DB_NAME_CLEAN%.corp.itcd.ru}"

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
CREDS=""
for NAME_VARIANT in "$DB_NAME_CLEAN" "${ENV_SUFFIXES[@]/#/$DB_NAME_CLEAN}"; do
	for PREFIX in cdp-database database; do
		VAULT_PATH="$PREFIX/creds/db-${ROLE}-${NAME_VARIANT}"
		TRIED_PATHS+=("$VAULT_PATH")
		CREDS=$(vault read -format=json "$VAULT_PATH" 2>/dev/null) && break 2
		CREDS=""
	done
done

# Fallback: fuzzy search via vault list (search configs, then fetch creds)
if [ -z "$CREDS" ]; then
	echo "Exact match not found, searching..." >&2
	MATCHES=()
	for PREFIX in cdp-database database; do
		LIST=$(vault list -format=json "$PREFIX/config" 2>/dev/null) || continue
		while IFS= read -r entry; do
			[ -n "$entry" ] && MATCHES+=("$PREFIX ${entry#db-}")
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
		MATCH_PREFIX=$(echo "${MATCHES[0]}" | awk '{print $1}')
		MATCH_NAME=$(echo "${MATCHES[0]}" | awk '{print $2}')
		VAULT_PATH="$MATCH_PREFIX/creds/db-${ROLE}-${MATCH_NAME}"
		echo "Found: $MATCH_PREFIX/config/db-$MATCH_NAME -> $VAULT_PATH" >&2
		CREDS=$(vault read -format=json "$VAULT_PATH" 2>/dev/null)
	elif [ "${#MATCHES[@]}" -gt 1 ]; then
		echo "Error: Multiple matches found for '$DB_NAME_CLEAN':" >&2
		for m in "${MATCHES[@]}"; do echo "  $(echo "$m" | awk '{print $1}')/config/db-$(echo "$m" | awk '{print $2}')" >&2; done
		echo "Please specify the exact name." >&2
		exit 1
	fi
fi

if [ -z "$CREDS" ]; then
	echo "Error: Failed to retrieve credentials from Vault" >&2
	echo "Tried paths:" >&2
	for p in "${TRIED_PATHS[@]}"; do echo "  $p" >&2; done
	exit 1
fi

# Extract username and password
USERNAME=$(echo "$CREDS" | jq -r '.data.username')
PASSWORD=$(echo "$CREDS" | jq -r '.data.password')

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ "$USERNAME" = "null" ] || [ "$PASSWORD" = "null" ]; then
	echo "Error: Could not extract credentials from Vault response" >&2
	exit 1
fi

if [ "$RAW_MODE" = true ]; then
	# Output raw credentials to stdout (for scripting)
	printf '%s\n%s\n' "$USERNAME" "$PASSWORD"
else
	# Copy to clipboard
	printf "Username: %s\nPassword: %s" "$USERNAME" "$PASSWORD" | pbcopy
	echo "Credentials copied to clipboard (role: $ROLE, expires in 12h)" >&2
fi

