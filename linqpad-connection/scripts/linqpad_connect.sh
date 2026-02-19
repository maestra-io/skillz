#!/bin/bash
# Create or refresh a LINQPad database connection using Vault credentials
# Usage: ./linqpad_connect.sh <env> <db-name> [reader|writer|owner]
#
# Steps:
#   1. Get connection config (host, database, driver) from Vault
#   2. Get credentials (username, password) from Vault (single read)
#   3. Create or update ConnectionsV2.xml entry
#   4. Add/update password in macOS Keychain
#   5. Restart LINQPad

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_SCRIPTS="$(cd "$SCRIPT_DIR/../../vault-helpers/scripts" 2>/dev/null && pwd)"
CONNECTIONS_FILE="$HOME/Library/Application Support/LINQPad/ConnectionsV2.xml"

if [ ! -d "$VAULT_SCRIPTS" ]; then
	echo "Error: vault-helpers not found at $VAULT_SCRIPTS" >&2
	exit 1
fi

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Error: Environment and database name required" >&2
	echo "Usage: $0 <env> <db-name> [reader|writer|owner]" >&2
	echo "Example: $0 maestra test-maestra" >&2
	exit 1
fi

ENV_NAME="$1"
DB_NAME="$2"
ROLE="${3:-reader}"

# Step 1: Get connection config
echo "Fetching connection config for $DB_NAME in $ENV_NAME..." >&2
CONFIG_OUTPUT=$("$VAULT_SCRIPTS/vault_config.sh" "$ENV_NAME" "$DB_NAME")
HOST=$(echo "$CONFIG_OUTPUT" | awk '{print $1}')
DATABASE=$(echo "$CONFIG_OUTPUT" | awk '{print $2}')
DRIVER=$(echo "$CONFIG_OUTPUT" | awk '{print $3}')

if [ -z "$HOST" ]; then
	echo "Error: Could not determine host from Vault config" >&2
	exit 1
fi

echo "  Host: $HOST" >&2
echo "  Database: $DATABASE" >&2
echo "  Driver: $DRIVER" >&2

# Step 2: Get credentials (single Vault read via --raw)
echo "Fetching credentials (role: $ROLE)..." >&2
CREDS_OUTPUT=$("$VAULT_SCRIPTS/vault_creds.sh" --raw "$ENV_NAME" "$DB_NAME" "$ROLE")
USERNAME=$(echo "$CREDS_OUTPUT" | head -1)
PASSWORD=$(echo "$CREDS_OUTPUT" | tail -1)

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
	echo "Error: Failed to get credentials" >&2
	exit 1
fi

echo "  Username: $USERNAME" >&2

# Map driver to EFProvider
case "$DRIVER" in
	sqlserver)
		EF_PROVIDER="Microsoft.EntityFrameworkCore.SqlServer"
		;;
	postgres)
		EF_PROVIDER="Npgsql.EntityFrameworkCore.PostgreSQL"
		;;
	*)
		echo "Error: Unknown driver '$DRIVER'. Expected sqlserver or postgres." >&2
		exit 1
		;;
esac

# Step 3: Create or update ConnectionsV2.xml
echo "Updating ConnectionsV2.xml..." >&2

if [ ! -f "$CONNECTIONS_FILE" ]; then
	echo "Error: ConnectionsV2.xml not found at $CONNECTIONS_FILE" >&2
	exit 1
fi

python3 << 'PYEOF' - "$HOST" "$DATABASE" "$USERNAME" "$EF_PROVIDER" "$DRIVER" "$CONNECTIONS_FILE" "$ROLE"
import sys
import uuid
import xml.etree.ElementTree as ET

host = sys.argv[1]
database = sys.argv[2]
username = sys.argv[3]
ef_provider = sys.argv[4]
driver = sys.argv[5]
connections_file = sys.argv[6]
role = sys.argv[7]

tree = ET.parse(connections_file)
root = tree.getroot()

# Find existing connection by Server + Database
existing = None
for conn in root.findall("Connection"):
    s = conn.find("Server")
    d = conn.find("Database")
    if s is not None and d is not None and s.text == host and d.text == database:
        # For non-reader roles, also match by DisplayName to avoid overwriting a different role
        if role != "reader":
            dn = conn.find("DisplayName")
            expected_display = f"{database}-{role}"
            if dn is not None and dn.text == expected_display:
                existing = conn
                break
        else:
            # Reader: match if no DisplayName or DisplayName doesn't end with a role suffix
            dn = conn.find("DisplayName")
            if dn is None or (not dn.text.endswith("-owner") and not dn.text.endswith("-writer")):
                existing = conn
                break

if existing is not None:
    # Update existing connection
    un = existing.find("UserName")
    if un is not None:
        un.text = username
    else:
        ET.SubElement(existing, "UserName").text = username
    print(f"Updated existing connection for {host}/{database}", file=sys.stderr)
else:
    # Create new connection
    conn = ET.SubElement(root, "Connection")
    ET.SubElement(conn, "ID").text = str(uuid.uuid4())
    ET.SubElement(conn, "NamingServiceVersion").text = "2"
    ET.SubElement(conn, "Persist").text = "true"
    drv = ET.SubElement(conn, "Driver")
    drv.set("Assembly", "(internal)")
    drv.set("PublicKeyToken", "no-strong-name")
    drv.text = "LINQPad.Drivers.EFCore.DynamicDriver"
    ET.SubElement(conn, "AllowDateOnlyTimeOnly").text = "true"
    ET.SubElement(conn, "SqlSecurity").text = "true"
    ET.SubElement(conn, "Server").text = host
    ET.SubElement(conn, "Database").text = database
    ET.SubElement(conn, "UserName").text = username
    if role != "reader":
        ET.SubElement(conn, "DisplayName").text = f"{database}-{role}"
    dd = ET.SubElement(conn, "DriverData")
    ET.SubElement(dd, "EncryptSqlTraffic").text = "True"
    ET.SubElement(dd, "PreserveNumeric1").text = "True"
    ET.SubElement(dd, "EFProvider").text = ef_provider
    print(f"Created new connection for {host}/{database}", file=sys.stderr)

# Write with XML declaration
tree.write(connections_file, encoding="utf-8", xml_declaration=True)
PYEOF

# Step 4: Add/update password in macOS Keychain
echo "Updating macOS Keychain..." >&2
KEYCHAIN_ACCOUNT=$(python3 -c "print(f'.database:${DRIVER}.${HOST} ${USERNAME}'.lower())")

security add-generic-password -s "LINQPad" -a "$KEYCHAIN_ACCOUNT" -w "$PASSWORD" -U ~/Library/Keychains/login.keychain-db
echo "  Keychain account: $KEYCHAIN_ACCOUNT" >&2

# Step 5: Restart LINQPad
echo "Restarting LINQPad..." >&2
pkill -x "LINQPad 8 beta" 2>/dev/null || pkill -f "LINQPad" 2>/dev/null || true
sleep 1
open "/Applications/LINQPad 8 beta.app" 2>/dev/null || open "/Applications/LINQPad.app" 2>/dev/null || echo "Warning: Could not open LINQPad app" >&2

echo "Done! Connection ready for $DATABASE on $HOST (role: $ROLE, expires in 12h)" >&2
