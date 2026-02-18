---
name: connect-sqlserver
description: Connect to SQL Server databases using Teleport and Vault across multiple environments (staging, prod, sigma, maestra). Use when the user asks to connect to a SQL Server database, run SQL queries via sqlcmd, or mentions a database name with an environment. Handles environment resolution, VNet, credential retrieval, and sqlcmd execution automatically.
---

# Connect to SQL Server via sqlcmd

Automated workflow for connecting to SQL Server databases using Teleport (tsh) and Vault. The AI executes queries directly via `sqlcmd` -- no GUI tool needed.

## Quick Start

When user requests SQL Server database connection:

1. Parse the database name and environment from the request
2. Run `connect.sh` to get connection details
3. Use the returned JSON to execute `sqlcmd` queries

```bash
cd /path/to/skill/scripts
JSON=$(./connect.sh <database-name> <environment> [reader|writer|owner])
```

**Examples:**
```bash
./connect.sh test-maestra maestra           # Reader access (default)
./connect.sh test-maestra maestra writer     # Write access
./connect.sh nexus-omega maestra owner       # Full access
```

The script outputs JSON to stdout (status messages go to stderr):
```json
{
  "host": "db-test-maestra.corp.itcd.ru",
  "database": "test-maestra",
  "username": "v-oidc-...",
  "password": "...",
  "env": "maestra",
  "role": "reader",
  "driver": "sqlserver",
  "sqlcmd": "sqlcmd -S db-test-maestra.corp.itcd.ru -U v-oidc-... -P '...' -C -d test-maestra"
}
```

After getting the JSON, execute queries with:
```bash
sqlcmd -S <host> -U '<username>' -P '<password>' -C -d <database> -Q "<SQL query>"
```

## Environments

| Name | Vault Address | Teleport Proxy | tsh command |
|------|--------------|----------------|-------------|
| staging | `https://vault-staging.mindbox.ru/` | `teleport.mindbox.ru` | `tshru` |
| prod | `https://vault.mindbox.ru/` | `teleport.mindbox.ru` | `tshru` |
| sigma | `https://vault.s.mindbox.ru/` | `teleport.mindbox.ru` | `tshru` |
| maestra | `https://vault.maestra.io/` | `teleport.maestra.io` | `tsh` |

**How to determine environment from user request:**
- User says "in maestra" or "maestra env" -> `maestra`
- User says "in prod" or "production" -> `prod`
- User says "in staging" or "stage" -> `staging`
- User says "in sigma" -> `sigma`
- If user does not specify environment, **ASK which environment**

## Detailed Workflow

If `connect.sh` fails or you need to do steps manually:

### Step 1: Resolve Environment

```bash
eval "$(./scripts/resolve_env.sh <env>)"
```

This sets: `VAULT_ADDR`, `TSH_BIN`, `TSH_PROXY`, `TSH_TELEPORT_HOME`, `ENV_NAME`.

### Step 2: Find Database in Teleport

```bash
./scripts/find_db.sh <db-name>
# Returns hostname, e.g.: db-test-maestra.corp.itcd.ru
```

Database naming: user says "test-maestra" -> script searches for "db-test-maestra" in Teleport apps.

### Step 3: Ensure VNet is Running

```bash
./scripts/ensure_vnet.sh
```

### Step 4: Get Connection Config from Vault

```bash
./scripts/get_vault_config.sh <db-name>
# Returns: host database driver (space-separated)
```

Reads `cdp-database/config/db-{name}` (fallback: `database/config/db-{name}`) and parses the `connection_url` to extract the host, database name, and driver.

### Step 5: Get Credentials from Vault

```bash
./scripts/get_vault_creds.sh <db-name> [reader|writer|owner]
# Returns: username password (space-separated)
```

Reads `cdp-database/creds/db-{role}-{name}` (fallback: `database/creds/db-{role}-{name}`).

### Step 6: Execute Query

```bash
sqlcmd -S <host> -U '<username>' -P '<password>' -C -d <database> -Q "<query>"
```

**Important:** Always use the `-C` flag (trust server certificate).

## Query Execution Patterns

**Single query:**
```bash
sqlcmd -S host -U user -P 'pass' -C -d dbname -Q "SELECT @@version;"
```

**List tables:**
```bash
sqlcmd -S host -U user -P 'pass' -C -d dbname -Q "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES ORDER BY TABLE_SCHEMA, TABLE_NAME;"
```

**Expanded row output (vertical):**
Use `-s "|"` for column separator when columns are wide.

## Credential Caching

After running `connect.sh`, **cache the connection details for the session**. Vault credentials last 12 hours -- reuse them for subsequent queries without re-running `connect.sh`. Only re-run if a query fails with authentication error.

## User Interaction Patterns

### Pattern 1: Explicit environment
User: "Connect to test-maestra in maestra env"
-> Run `connect.sh test-maestra maestra reader`

### Pattern 2: Query request without prior connection
User: "Query the Staff table in test-maestra (maestra)"
-> Run `connect.sh test-maestra maestra reader`, then execute the query

### Pattern 3: Follow-up query (already connected)
User: "Now show me the segmentations"
-> Reuse cached credentials, run sqlcmd directly

### Pattern 4: No environment specified
User: "Connect to test-maestra"
-> ASK the user which environment (staging/prod/sigma/maestra)

### Pattern 5: Write access
User: "Connect to test-maestra in maestra with write access"
-> Run `connect.sh test-maestra maestra writer`

## Error Handling

**Database not found:**
- Verify the name spelling
- List available databases: check find_db.sh output
- Ensure Teleport login is current

**Vault credentials fail:**
- Check Vault authentication: `VAULT_ADDR=<addr> vault token lookup`
- Re-login: `VAULT_ADDR=<addr> vault login -method=oidc`
- The script tries both `cdp-database` and `database` paths automatically

**sqlcmd login failed:**
- Ensure `-d <database>` flag is provided (SQL Server requires it)
- Ensure `-C` flag is provided (trust server certificate)
- Get fresh credentials -- old ones may have expired

**VNet not routing:**
- Check if VNet is running: `pgrep -f "tsh vnet"`
- Restart VNet if needed
- Verify Teleport login for the correct proxy

## Security Notes

- Credentials are dynamic with 12-hour TTL
- Never log or store passwords in plain text
- Default to reader role unless write access is explicitly needed
- Each connection gets fresh credentials from Vault
