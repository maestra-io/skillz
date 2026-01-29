#!/bin/bash
# Clean up broken DBeaver connections
# Usage: ./cleanup_connections.sh [connection-name-pattern]

set -e

DBEAVER_WORKSPACE="$HOME/Library/DBeaverData/workspace6"
CONN_CONFIG="$DBEAVER_WORKSPACE/General/.dbeaver/data-sources.json"

if [ ! -f "$CONN_CONFIG" ]; then
    echo "No DBeaver configuration found at: $CONN_CONFIG"
    exit 0
fi

# Backup current config
BACKUP="$CONN_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
cp "$CONN_CONFIG" "$BACKUP"
echo "✓ Backup created: $BACKUP"

# Optional: filter by connection name pattern
PATTERN="${1:-}"

if [ -n "$PATTERN" ]; then
    echo "🧹 Cleaning connections matching: $PATTERN"
else
    echo "🧹 Cleaning all connections..."
fi

# Show current connections
echo ""
echo "Current connections:"
jq -r '.connections | keys[]' "$CONN_CONFIG" 2>/dev/null | while read conn_id; do
    CONN_NAME=$(jq -r ".connections[\"$conn_id\"].name" "$CONN_CONFIG")
    echo "  - $CONN_NAME ($conn_id)"
done

echo ""
read -p "Do you want to remove all connections? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Create new config with empty connections
    jq '.connections = {}' "$CONN_CONFIG" > "$CONN_CONFIG.tmp"
    mv "$CONN_CONFIG.tmp" "$CONN_CONFIG"
    echo "✓ All connections removed"
    echo "✓ Restart DBeaver to apply changes"
else
    echo "✗ Cleanup cancelled"
    exit 0
fi
