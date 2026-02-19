---
name: linqpad-connection
description: Create or refresh LINQPad database connections using Vault credentials. Use when the user asks to connect to a database in LINQPad, refresh LINQPad creds, or set up a LINQPad connection.
---

# LINQPad Connection

Automates the full LINQPad database connection workflow: fetches Vault credentials (via vault-helpers), configures ConnectionsV2.xml, stores password in macOS Keychain, and restarts LINQPad.

Depends on: `../vault-helpers/` (sibling skill directory) for Vault operations.

## Script

```bash
./scripts/linqpad_connect.sh <env> <db-name> [reader|writer|owner]
```

**Examples:**
```bash
./scripts/linqpad_connect.sh maestra test-maestra           # Reader (default)
./scripts/linqpad_connect.sh maestra test-maestra writer     # Write access
./scripts/linqpad_connect.sh prod nexus-omega owner          # Full access
```

The script:
1. Ensures Teleport VNet is running (env-aware, via vault-helpers `ensure_vnet.sh`)
2. Fetches connection config (host, database, driver) via vault-helpers `vault_config.sh`
3. Fetches credentials (username, password) via vault-helpers `vault_creds.sh --raw` (single Vault read)
4. Creates or updates the connection entry in `~/Library/Application Support/LINQPad/ConnectionsV2.xml`
5. Adds/updates password in macOS Keychain (service: `LINQPad`, account lowercased)
6. Restarts LINQPad to pick up changes

## How to Determine Environment

- User says "in maestra" or "maestra env" -> `maestra`
- User says "in prod" or "production" -> `prod`
- User says "in staging" or "stage" -> `staging`
- User says "in sigma" -> `sigma`
- User says "in omega" -> `maestra`
- User says "in beta" or "in stable" -> `prod`
- If not specified, **ASK which environment**

## Workflow

When user asks for a LINQPad connection (or to connect/refresh a database in LINQPad):

1. Parse environment, database name, and optional role from request
2. Run:
   ```bash
   cd <skill-dir> && ./scripts/linqpad_connect.sh <env> <db-name> [role]
   ```
3. Report that the connection is ready and LINQPad has been restarted

## Security

- **NEVER print, echo, or include credentials (username or password) in your responses.** The script handles credential storage securely.
- Default to reader role unless write access is explicitly requested

## Error Handling

**Token expired or missing:**
```bash
cd <vault-helpers-skill-dir> && ./scripts/vault_login.sh <env>
```
Then retry the linqpad_connect.sh command.

**Credentials path not found:**
- Scripts try exact name, env suffixes, then fuzzy search automatically
- If fuzzy search returns multiple matches, pick the right one and retry with the exact name

**Environment not recognized:**
- Valid environments: staging, prod, sigma, maestra

**VNet running for wrong proxy:**
- The script checks that VNet is running for the correct Teleport proxy (e.g. `teleport.maestra.io` for maestra, `teleport.mindbox.ru` for staging/prod/sigma)
- If VNet is running for a different proxy, stop it with `sudo pkill -f 'tsh.*vnet'` and retry automatically

**LINQPad not found:**
- The script tries "LINQPad 8 beta.app" first, then "LINQPad.app"
