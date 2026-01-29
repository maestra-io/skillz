---
name: connect-postgres-dbeaver
description: Automate PostgreSQL database connections through DBeaver using Teleport and Vault. Use when the user asks to connect to a database, mentions DBeaver, Teleport databases, or specific database names like nexus, omega, etc. Handles authentication, VNet, credentials retrieval, and DBeaver launch automatically.
---

# Connect to PostgreSQL via DBeaver

Fully automated workflow for connecting to PostgreSQL databases through DBeaver using Teleport (tsh) and Vault for credential management. No manual password entry required.

## Quick Start

When user requests database connection:

1. Identify the database name from request
2. Find the Teleport app using `tsh app ls`
3. Ensure `tsh vnet` is running
4. Verify network connectivity to the database
5. Retrieve credentials from Vault
6. Launch DBeaver with connection parameters

## Complete Automated Workflow

Use the main `connect.sh` script which handles everything automatically:

```bash
cd /path/to/skill/scripts
./connect.sh <database-name> [reader|writer|owner]
```

**Examples:**
```bash
./connect.sh nexus              # Read-only access
./connect.sh nexus writer       # Read/write access  
./connect.sh nexus owner        # Full access
```

The script performs these steps automatically:

### Step 0: Prerequisites Check
- Verifies tsh, vault, dbeaver, jq are installed
- Provides installation commands if missing
- Sets required environment variables (VAULT_ADDR)

### Step 1: Find Database Application

Search for the database in Teleport apps using JSON API:

```bash
tsh app ls --format=json | jq -r '.[] | select(.metadata.name | contains("db-name")) | .spec.public_addr'
```

**Why JSON format?**
- Text output can be truncated when terminal width is narrow
- JSON provides structured, reliable access to all fields
- Extracts `metadata.name` for matching and `spec.public_addr` for hostname

**Database naming patterns:**
- User says "nexus" → look for `db-nexus-omega`
- User says "db-nexus" → look for `db-nexus-omega`
- Database apps always have prefix `db-`
- Full domain format: `db-<name>-<env>.teleport.maestra.io`

**Example JSON structure:**
```json
{
  "metadata": {
    "name": "db-nexus-omega"
  },
  "spec": {
    "public_addr": "db-nexus-omega.teleport.maestra.io"
  }
}
```

Extract the `public_addr` field (e.g., `db-nexus-omega.teleport.maestra.io`).

### Step 2: Ensure Teleport VNet is Running

Check if `tsh vnet` is already running:

```bash
pgrep -f "tsh vnet" > /dev/null
```

If not running, start it:

```bash
tsh vnet &
```

**Important:** Wait 2-3 seconds after starting vnet for network to initialize.

### Step 3: Verify Network Connectivity

Ping the database hostname to verify vnet routing:

```bash
ping -c 2 <db-hostname>
```

The IP should be from vnet range (typically 100.x.x.x range).

**If ping fails:**
- Wait a few more seconds for vnet to initialize
- Try ping again
- If still fails, check `tsh status` for authentication

### Step 4: Retrieve Vault Credentials

Vault path pattern: `database/creds/db-<role>-<dbname>-<env>`

**Default role: reader**
- Path: `database/creds/db-reader-<dbname>-<env>`

**Available roles:**
- `db-reader-<dbname>-<env>` - read-only access (default)
- `db-writer-<dbname>-<env>` - read/write access
- `db-owner-<dbname>-<env>` - full owner access

Get credentials from Vault (vault.maestra.io):

```bash
vault read -format=json database/creds/db-reader-nexus-omega | jq -r '.data | .username, .password'
```

**Output format:**
```
v-token-db-reader-nexus-omega-AbCd123
<password>
```

Extract username (first line) and password (second line).

### Step 5: Launch DBeaver

DBeaver connection parameters:
- **Driver:** PostgreSQL
- **Host:** Extract hostname from teleport app (e.g., `db-nexus-omega.teleport.maestra.io`)
- **Port:** 5432 (default PostgreSQL)
- **Database:** Usually same as app name without prefix (e.g., `nexus` from `db-nexus-omega`)
- **Username:** From Vault
- **Password:** From Vault

Launch DBeaver with CLI (if available) or provide instructions for manual setup.

**DBeaver CLI approach (MacOS):**
```bash
open -a DBeaver
```

Then create connection programmatically or provide connection string.

**Connection URL format:**
```
postgresql://<username>:<password>@<hostname>:5432/<database>
```

## User Interaction Patterns

### Pattern 1: Simple request
User: "Connect to nexus database"
→ Use reader role by default

### Pattern 2: Specific role request
User: "Connect to nexus with write access"
→ Use db-writer role

User: "Connect to nexus as owner"
→ Use db-owner role

### Pattern 3: Alternative naming
User: "Connect to db-nexus-omega"
→ Search for exact match first, fallback to pattern matching

## Utility Scripts

The `scripts/` directory contains helper utilities:

**find_db.sh** - Search for database in tsh apps using JSON API
```bash
./scripts/find_db.sh nexus
# Returns: db-nexus-omega.teleport.maestra.io
```

This script uses `tsh app ls --format=json` for reliable parsing instead of text output, which can be truncated. It extracts:
- `metadata.name` to match database names
- `spec.public_addr` to get the connection hostname

**ensure_vnet.sh** - Check and start vnet if needed
```bash
./scripts/ensure_vnet.sh
# Returns: "running" or starts vnet
```

**get_vault_creds.sh** - Retrieve credentials from Vault
```bash
./scripts/get_vault_creds.sh db-nexus-omega reader
# Returns: username password (space-separated)
```

**launch_dbeaver.sh** - Open DBeaver with connection
```bash
./scripts/launch_dbeaver.sh <hostname> <database> <username> <password>
```

## Error Handling

**Database not found:**
- Verify user has access: `tsh app ls`
- Check authentication: `tsh status`
- Try broader search without prefix

**Vnet fails to start:**
- Check if user is logged in: `tsh status`
- Re-login if needed: `tsh login --proxy=teleport.maestra.io`

**Vault credentials fail:**
- Verify Vault authentication: `vault token lookup`
- Check role exists in Vault
- Try alternative role (reader vs writer)

**Connection fails:**
- Verify ping works to hostname
- Check port 5432 is accessible
- Confirm credentials are fresh (Vault generates dynamic creds with TTL)

## Prerequisites

Ensure these tools are installed:
- `tsh` (Teleport client) - `brew install teleport`
- `vault` (Vault CLI) - `brew install vault`
- `dbeaver` (DBeaver database tool) - `brew install --cask dbeaver-community`
- `jq` (JSON processor) - `brew install jq`

The scripts automatically check for prerequisites and provide installation instructions if missing.

## Important Configuration

### Teleport Proxy
Always use `--proxy=teleport.maestra.io` flag with tsh commands to avoid proxy conflicts:
```bash
tsh --proxy=teleport.maestra.io app ls
tsh --proxy=teleport.maestra.io status
```

### Vault Address
Set the Vault address environment variable:
```bash
export VAULT_ADDR=https://vault.maestra.io
```

The scripts automatically set this if not present.

### DBeaver Password Saving
DBeaver must be launched via CLI with specific flags to save passwords:
- `savePassword=true` - Critical for automatic login
- `connect=true` - Auto-connect on startup
- `save=true` - Persist connection config

## Troubleshooting & Corner Cases

### Case 1: Teleport Version Warning
**Symptom:** Warning about incompatible tsh versions (client 18.x vs server 16.x)
**Solution:** Add `--skip-version-check` flag or downgrade tsh
```bash
tsh --proxy=teleport.maestra.io --skip-version-check app ls
```

### Case 2: Multiple Teleport Profiles
**Symptom:** Active profile expired or wrong cluster selected
**Solution:** Explicitly specify proxy in all commands
```bash
# Check current profile
tsh status

# Switch to maestra.io profile
tsh --proxy=teleport.maestra.io status
```

### Case 3: VNet Not Starting
**Symptom:** `tsh vnet` fails to start
**Causes:**
- Not logged in to Teleport
- Another vnet instance running on different proxy

**Solutions:**
```bash
# Check login status
tsh --proxy=teleport.maestra.io status

# Kill existing vnet
pkill -f "tsh vnet"

# Start fresh vnet
tsh vnet --proxy=teleport.maestra.io &
```

### Case 4: Vault Connection Refused
**Symptom:** `dial tcp 127.0.0.1:8200: connect: connection refused`
**Cause:** VAULT_ADDR not set
**Solution:**
```bash
export VAULT_ADDR=https://vault.maestra.io
vault token lookup
```

### Case 5: Password Dialog Appears in DBeaver
**Symptom:** DBeaver shows SCRAM authentication error despite providing password
**Causes:**
- DBeaver didn't save password properly
- Old broken connection exists

**Solutions:**
1. Close DBeaver completely
2. Run connection script again - it will:
   - Get fresh credentials from Vault
   - Clean up broken connections
   - Launch DBeaver with proper password saving flags

### Case 6: Expired Credentials
**Symptom:** Connection works initially but fails after some time
**Cause:** Vault credentials expired (12-hour TTL)
**Solution:** Simply reconnect - script will fetch fresh credentials automatically

### Case 7: Database Not Found
**Symptom:** `Database 'name' not found in Teleport apps`
**Causes:**
- Typo in database name
- Not authenticated to Teleport
- No access to requested database

**Solutions:**
```bash
# List all available databases
tsh --proxy=teleport.maestra.io app ls | grep "^db-"

# Check authentication
tsh --proxy=teleport.maestra.io status

# Re-login if needed
tsh login --proxy=teleport.maestra.io
```

### Case 8: Ping Fails But Connection Might Work
**Symptom:** Warning that ping failed during connectivity check
**Cause:** VNet routing not fully initialized or ICMP blocked
**Solution:** This is usually harmless - DBeaver connection should still work

### Case 9: Wrong Vault Role
**Symptom:** `Failed to retrieve credentials from Vault`
**Cause:** Requested role doesn't exist for this database
**Solution:** Try different role:
```bash
# Try reader first (most common)
./get_vault_creds.sh nexus-omega reader

# If reader doesn't exist, try writer
./get_vault_creds.sh nexus-omega writer
```

### Case 10: DBeaver Already Running
**Symptom:** Multiple DBeaver windows or old connections visible
**Solution:** Scripts automatically:
1. Kill existing DBeaver instance
2. Wait 2 seconds for cleanup
3. Launch fresh instance with new connection

## Best Practices

1. **Always use the automated script** - It handles all corner cases
2. **Default to reader role** - Only request writer/owner when needed
3. **Close DBeaver before reconnecting** - Prevents duplicate connections
4. **Check Teleport login status first** - Saves debugging time
5. **Use full workflow script** - `connect.sh` includes all checks

## Security Notes

- Credentials from Vault are dynamic and have TTL (12 hours)
- Never log or store passwords in plain text
- Use reader role by default unless write access is explicitly needed
- Vault credentials are temporary and expire automatically
- Each connection gets fresh credentials from Vault
