#!/bin/bash
# Complete automated connection workflow
# Usage: ./connect.sh <db-name> [reader|writer|owner]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DB_NAME="$1"
ROLE="${2:-reader}"

if [ -z "$DB_NAME" ]; then
    echo -e "${RED}Error: Database name required${NC}"
    echo "Usage: $0 <db-name> [reader|writer|owner]"
    echo ""
    echo "Examples:"
    echo "  $0 nexus"
    echo "  $0 nexus writer"
    echo "  $0 db-nexus-omega owner"
    exit 1
fi

# Set Vault address
export VAULT_ADDR="${VAULT_ADDR:-https://vault.maestra.io}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  PostgreSQL Database Connection Workflow${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 0: Prerequisites check
echo -e "${YELLOW}🔧 Step 0/5: Checking prerequisites...${NC}"

# Check tsh
if ! command -v tsh > /dev/null 2>&1; then
    echo -e "${RED}✗ tsh (Teleport client) not found${NC}"
    echo "Install with: brew install teleport"
    exit 1
fi

# Check vault
if ! command -v vault > /dev/null 2>&1; then
    echo -e "${RED}✗ vault CLI not found${NC}"
    echo "Install with: brew install vault"
    exit 1
fi

# Check jq
if ! command -v jq > /dev/null 2>&1; then
    echo -e "${RED}✗ jq not found${NC}"
    echo "Install with: brew install jq"
    exit 1
fi

# Check DBeaver
if [ ! -f "/Applications/DBeaver.app/Contents/MacOS/dbeaver" ]; then
    echo -e "${RED}✗ DBeaver not found${NC}"
    echo "Install with: brew install --cask dbeaver-community"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Step 1: Find database
echo -e "${YELLOW}🔍 Step 1/5: Finding database...${NC}"
HOSTNAME=$("$SCRIPT_DIR/find_db.sh" "$DB_NAME")
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to find database${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found: $HOSTNAME${NC}"
echo ""

# Step 2: Ensure vnet
echo -e "${YELLOW}🌐 Step 2/5: Ensuring VNet is running...${NC}"
"$SCRIPT_DIR/ensure_vnet.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to start VNet${NC}"
    exit 1
fi
echo ""

# Step 3: Verify connectivity
echo -e "${YELLOW}🏓 Step 3/5: Verifying connectivity...${NC}"
if ping -c 2 "$HOSTNAME" > /dev/null 2>&1; then
    PING_IP=$(ping -c 1 "$HOSTNAME" | grep -oE '\([0-9.]+\)' | tr -d '()')
    echo -e "${GREEN}✓ Database is reachable at $PING_IP${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Ping failed, but connection might still work${NC}"
fi
echo ""

# Step 4: Get credentials
echo -e "${YELLOW}🔑 Step 4/5: Getting credentials from Vault (role: $ROLE)...${NC}"
CREDS=$("$SCRIPT_DIR/get_vault_creds.sh" "$HOSTNAME" "$ROLE")
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to get credentials${NC}"
    exit 1
fi
read USERNAME PASSWORD <<< "$CREDS"
echo -e "${GREEN}✓ Credentials retrieved: $USERNAME${NC}"
echo ""

# Extract database name from hostname
# db-nexus-omega.teleport.maestra.io -> nexus
# db-ab-tests-omega.teleport.maestra.io -> ab-tests
DB_CLEAN=$(echo "$HOSTNAME" | sed 's/^db-//' | sed 's/-omega.*//')

# Step 5: Launch DBeaver
echo -e "${YELLOW}🚀 Step 5/5: Launching DBeaver...${NC}"
"$SCRIPT_DIR/launch_dbeaver.sh" "$HOSTNAME" "$DB_CLEAN" "$USERNAME" "$PASSWORD"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Connection workflow completed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
