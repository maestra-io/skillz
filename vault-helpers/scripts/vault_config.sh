#!/bin/bash
# Get database connection config from Vault (host, database name, driver)
# Usage: ./vault_config.sh <env> <db-name>
# Outputs: host database driver (space-separated)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/_vault_common.sh"

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Error: Environment and database name required" >&2
	echo "Usage: $0 <env> <db-name>" >&2
	exit 1
fi

ENV_NAME="$1"
DB_NAME="$2"

vault_require_jq
vault_init "$ENV_NAME"

DB_NAME_CLEAN=$(vault_clean_db_name "$DB_NAME")

_config_path() { echo "$1/config/db-$2"; }
vault_resolve_path "$ENV_NAME" "$DB_NAME_CLEAN" _config_path

# Extract connection_url from the nested connection_details
CONN_URL=$(echo "$VAULT_RESULT" | jq -r '.data.connection_details.connection_url // .data.connection_url // empty')

if [ -z "$CONN_URL" ]; then
	echo "Error: No connection_url found in Vault config" >&2
	exit 1
fi

# Parse URL using python3 urllib.parse (handles all URL formats correctly)
read -r HOST DATABASE DRIVER < <(python3 -c "
from urllib.parse import urlparse, parse_qs
import sys
p = urlparse(sys.argv[1])
host = p.hostname or ''
if p.port:
    host = f'{host}:{p.port}'
database = parse_qs(p.query).get('database', [''])[0] or p.path.strip('/')
scheme = p.scheme
driver = scheme.split('+')[0] if '+' in scheme else scheme
print(f'{host} {database} {driver}')
" "$CONN_URL")

if [ -z "$HOST" ]; then
	echo "Error: Could not parse host from connection_url" >&2
	exit 1
fi

# Output space-separated: host database driver
echo "$HOST $DATABASE $DRIVER"
