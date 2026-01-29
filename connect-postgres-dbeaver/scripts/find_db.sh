#!/bin/bash
# Find database application in Teleport using JSON API
# Usage: ./find_db.sh <db-name>

set -e

if [ -z "$1" ]; then
    echo "Error: Database name required" >&2
    echo "Usage: $0 <db-name>" >&2
    exit 1
fi

DB_NAME="$1"

# Check if logged in to Teleport
if ! tsh --proxy=teleport.maestra.io status > /dev/null 2>&1; then
    echo "Error: Not logged in to Teleport" >&2
    echo "Please run: tsh login --proxy=teleport.maestra.io" >&2
    exit 1
fi

# Check if jq is installed
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
# This properly handles truncated text output by using structured JSON
HOSTNAME=$(tsh --proxy=teleport.maestra.io app ls --format=json 2>/dev/null | \
    jq -r --arg search "$SEARCH_NAME" \
    '.[] | select(.metadata.name != null and (.metadata.name | contains($search))) | .spec.public_addr' | \
    head -1)

if [ -z "$HOSTNAME" ]; then
    echo "Error: Database '$DB_NAME' not found in Teleport apps" >&2
    echo "Available databases:" >&2
    tsh --proxy=teleport.maestra.io app ls --format=json 2>/dev/null | \
        jq -r '.[] | select(.metadata.name != null and (.metadata.name | startswith("db-"))) | .metadata.name' | \
        sort >&2 || echo "No databases found" >&2
    exit 1
fi

echo "$HOSTNAME"
