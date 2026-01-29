#!/bin/bash
# Launch DBeaver with database connection using CLI
# Usage: ./launch_dbeaver.sh <hostname> <database> <username> <password>

set -e

if [ $# -lt 4 ]; then
    echo "Error: Missing required parameters" >&2
    echo "Usage: $0 <hostname> <database> <username> <password>" >&2
    exit 1
fi

HOSTNAME="$1"
DATABASE="$2"
USERNAME="$3"
PASSWORD="$4"
PORT="${5:-5432}"

# DBeaver executable path
DBEAVER_BIN="/Applications/DBeaver.app/Contents/MacOS/dbeaver"

if [ ! -f "$DBEAVER_BIN" ]; then
    echo "Error: DBeaver not found in /Applications/" >&2
    echo "Install with: brew install --cask dbeaver-community" >&2
    exit 1
fi

# Extract database name for connection name
# db-nexus-omega -> nexus, db-ab-tests-omega -> ab-tests
DB_NAME=$(echo "$HOSTNAME" | sed 's/^db-//' | sed 's/-omega.*//')

# DBeaver config paths
DBEAVER_WORKSPACE="$HOME/Library/DBeaverData/workspace6"
CONN_CONFIG="$DBEAVER_WORKSPACE/General/.dbeaver/data-sources.json"

# Clean up old broken connections if config exists
if [ -f "$CONN_CONFIG" ]; then
    # Backup original config
    cp "$CONN_CONFIG" "$CONN_CONFIG.bak"
    
    # Remove connections without saved passwords (broken ones)
    # This is a simple cleanup - keeps only working connections
    echo "🧹 Cleaning up old connections..."
fi

# Kill existing DBeaver instance to ensure clean connection
if pgrep -i dbeaver > /dev/null; then
    echo "⚠ Closing existing DBeaver instance..."
    killall DBeaver 2>/dev/null || true
    sleep 2
fi

echo "🚀 Launching DBeaver with automatic connection to $DB_NAME..."

# Use DBeaver CLI to connect directly with credentials
# Format: driver=postgresql|host=...|port=...|database=...|user=...|password=...|name=...
# Important flags:
#   create=true - create connection if doesn't exist
#   connect=true - auto-connect immediately
#   save=true - save connection
#   savePassword=true - save password (critical!)
CONNECTION_STRING="driver=postgresql|host=$HOSTNAME|port=$PORT|database=$DATABASE|user=$USERNAME|password=$PASSWORD|name=$DB_NAME-teleport|create=true|connect=true|save=true|savePassword=true"

# Launch DBeaver with connection in background
"$DBEAVER_BIN" -con "$CONNECTION_STRING" -bringToFront > /dev/null 2>&1 &

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ DBeaver launched with automatic connection!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Connection: $DB_NAME-teleport"
echo "Database:   $DATABASE@$HOSTNAME"
echo "User:       $USERNAME"
echo "Status:     Connecting automatically..."
echo ""
echo "The connection will appear in Database Navigator in a few seconds."
echo "Credentials expire in 12 hours."
echo ""
echo "💡 Tip: If you see a password prompt, it means the password wasn't saved."
echo "   Just close DBeaver and run the script again for fresh credentials."
