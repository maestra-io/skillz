#!/bin/bash
# Find database application in Teleport using JSON API (env-aware)
# Usage: ./find_db.sh <db-name>
# Requires: TSH_BIN, TSH_PROXY, TSH_TELEPORT_HOME (from resolve_env.sh)

set -e

if [ -z "$1" ]; then
	echo "Error: Database name required" >&2
	echo "Usage: $0 <db-name>" >&2
	exit 1
fi

DB_NAME="$1"

run_tsh() {
	if [ -n "$TSH_TELEPORT_HOME" ]; then
		TELEPORT_HOME="$TSH_TELEPORT_HOME" "$TSH_BIN" --proxy "$TSH_PROXY" "$@"
	else
		"$TSH_BIN" --proxy "$TSH_PROXY" "$@"
	fi
}

# Check if logged in to Teleport
if ! run_tsh status > /dev/null 2>&1; then
	echo "Error: Not logged in to Teleport ($TSH_PROXY)" >&2
	if [ "$TSH_PROXY" = "teleport.mindbox.ru" ]; then
		echo "Please run: tshru login" >&2
	else
		echo "Please run: tsh login --proxy=$TSH_PROXY" >&2
	fi
	exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
	echo "Error: jq is required for JSON parsing" >&2
	echo "Install with: brew install jq" >&2
	exit 1
fi

# Add db- prefix if not present
if [[ ! "$DB_NAME" =~ ^db- ]]; then
	SEARCH_NAME="db-$DB_NAME"
else
	SEARCH_NAME="$DB_NAME"
fi

# Search for the database using JSON output
HOSTNAME=$(run_tsh app ls --format=json 2>/dev/null | \
	jq -r --arg search "$SEARCH_NAME" \
	'.[] | select(.metadata.name != null and (.metadata.name | contains($search))) | .spec.public_addr' | \
	head -1)

if [ -z "$HOSTNAME" ]; then
	echo "Error: Database '$DB_NAME' not found in Teleport apps ($TSH_PROXY)" >&2
	echo "Available databases:" >&2
	run_tsh app ls --format=json 2>/dev/null | \
		jq -r '.[] | select(.metadata.name != null and (.metadata.name | startswith("db-"))) | .metadata.name' | \
		sort >&2 || echo "No databases found" >&2
	exit 1
fi

echo "$HOSTNAME"
