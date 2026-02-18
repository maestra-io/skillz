#!/bin/bash
# Complete automated SQL Server connection workflow
# Usage: ./connect.sh <db-name> <env> [reader|writer|owner]
# Outputs JSON with connection details for sqlcmd

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DB_NAME="$1"
ENV="$2"
ROLE="${3:-reader}"

if [ -z "$DB_NAME" ] || [ -z "$ENV" ]; then
	echo -e "${RED}Error: Database name and environment required${NC}" >&2
	echo "Usage: $0 <db-name> <env> [reader|writer|owner]" >&2
	echo "" >&2
	echo "Environments: staging, prod, sigma, maestra" >&2
	echo "" >&2
	echo "Examples:" >&2
	echo "  $0 test-maestra maestra" >&2
	echo "  $0 test-maestra maestra writer" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "${BLUE}  SQL Server Database Connection Workflow${NC}" >&2
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo "" >&2

# Step 0: Prerequisites check
echo -e "${YELLOW}Step 0/5: Checking prerequisites...${NC}" >&2

if ! command -v vault > /dev/null 2>&1; then
	echo -e "${RED}Error: vault CLI not found. Install with: brew install vault${NC}" >&2
	exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
	echo -e "${RED}Error: jq not found. Install with: brew install jq${NC}" >&2
	exit 1
fi

if ! command -v sqlcmd > /dev/null 2>&1; then
	echo -e "${RED}Error: sqlcmd not found. Install with: brew install sqlcmd${NC}" >&2
	exit 1
fi

echo -e "${GREEN}All prerequisites installed${NC}" >&2
echo "" >&2

# Step 1: Resolve environment
echo -e "${YELLOW}Step 1/5: Resolving environment '$ENV'...${NC}" >&2
eval "$("$SCRIPT_DIR/resolve_env.sh" "$ENV")"
echo -e "${GREEN}Vault: $VAULT_ADDR${NC}" >&2
echo -e "${GREEN}Teleport: $TSH_PROXY${NC}" >&2
echo "" >&2

# Step 2: Find database in Teleport
echo -e "${YELLOW}Step 2/5: Finding database in Teleport...${NC}" >&2
TELEPORT_HOST=$("$SCRIPT_DIR/find_db.sh" "$DB_NAME")
echo -e "${GREEN}Found: $TELEPORT_HOST${NC}" >&2
echo "" >&2

# Step 3: Ensure VNet is running
echo -e "${YELLOW}Step 3/5: Ensuring VNet is running...${NC}" >&2
"$SCRIPT_DIR/ensure_vnet.sh" >&2
echo "" >&2

# Step 4: Get connection config from Vault
echo -e "${YELLOW}Step 4/5: Getting connection config from Vault...${NC}" >&2
CONFIG_OUTPUT=$("$SCRIPT_DIR/get_vault_config.sh" "$DB_NAME")
read HOST DATABASE DRIVER <<< "$CONFIG_OUTPUT"
echo -e "${GREEN}Host: $HOST${NC}" >&2
echo -e "${GREEN}Database: $DATABASE${NC}" >&2
echo -e "${GREEN}Driver: $DRIVER${NC}" >&2
echo "" >&2

# Step 5: Get credentials from Vault
echo -e "${YELLOW}Step 5/5: Getting credentials from Vault (role: $ROLE)...${NC}" >&2
CREDS=$("$SCRIPT_DIR/get_vault_creds.sh" "$DB_NAME" "$ROLE")
read USERNAME PASSWORD <<< "$CREDS"
echo -e "${GREEN}Credentials retrieved: $USERNAME${NC}" >&2
echo "" >&2

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "${GREEN}  Connection ready!${NC}" >&2
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "Credentials expire in 12 hours." >&2

# Output JSON to stdout (all status messages go to stderr)
jq -n \
	--arg host "$HOST" \
	--arg database "$DATABASE" \
	--arg username "$USERNAME" \
	--arg password "$PASSWORD" \
	--arg env "$ENV" \
	--arg role "$ROLE" \
	--arg driver "$DRIVER" \
	--arg sqlcmd "sqlcmd -S $HOST -U $USERNAME -P '$PASSWORD' -C -d $DATABASE" \
	'{host: $host, database: $database, username: $username, password: $password, env: $env, role: $role, driver: $driver, sqlcmd: $sqlcmd}'
