---
name: vault-helpers
description: Get database credentials from Vault, login to Vault, switch Vault environments, and copy credentials to clipboard. Use when the user asks to get DB creds, login to Vault, or switch Vault environment.
---

# Vault Helpers

Standalone helpers for HashiCorp Vault operations across Mindbox/Maestra environments.

## Scripts

All scripts are in `./scripts/` relative to this skill's directory.

### Get Database Credentials

```bash
./scripts/vault_creds.sh <env> <db-name> [reader|writer|owner]
```

**Examples:**
```bash
./scripts/vault_creds.sh maestra test-maestra           # Reader (default)
./scripts/vault_creds.sh maestra test-maestra writer     # Write access
./scripts/vault_creds.sh prod nexus-omega owner          # Full access
```

Copies credentials to clipboard via pbcopy. Status messages go to stderr.

With `--raw` flag, outputs `USERNAME\nPASSWORD` to stdout instead (for scripting):
```bash
./scripts/vault_creds.sh --raw maestra test-maestra
```

### Get Database Connection Config

```bash
./scripts/vault_config.sh <env> <db-name>
```

Outputs `host database driver` (space-separated) to stdout.

### Login to Vault

```bash
./scripts/vault_login.sh <env>
```

Opens OIDC login in browser, saves token to `~/.vault-tokens/{env}`.

### Resolve Environment

```bash
eval "$(./scripts/resolve_env.sh <env>)"
```

Sets: `VAULT_ADDR`, `TSH_BIN`, `TSH_PROXY`, `TSH_TELEPORT_HOME`, `ENV_NAME`.

## Environments

| Name | Vault Address | Teleport Proxy |
|------|--------------|----------------|
| staging | `https://vault-staging.mindbox.ru/` | `teleport.mindbox.ru` |
| prod | `https://vault.mindbox.ru/` | `teleport.mindbox.ru` |
| sigma | `https://vault.s.mindbox.ru/` | `teleport.mindbox.ru` |
| maestra | `https://vault.maestra.io/` | `teleport.maestra.io` |

## How to Determine Environment

- User says "in maestra" or "maestra env" -> `maestra`
- User says "in prod" or "production" -> `prod`
- User says "in staging" or "stage" -> `staging`
- User says "in sigma" -> `sigma`
- User says "in omega" -> `maestra`
- User says "in beta" or "in stable" -> `prod`
- If not specified, **ASK which environment**

## Workflow

When user asks for database credentials:

1. Parse environment and database name from request
2. Run `vault_creds.sh`:
   ```bash
   cd <skill-dir> && ./scripts/vault_creds.sh <env> <db-name> [role]
   ```
3. Report that credentials are copied to clipboard

## Security

- **NEVER print, echo, or include credentials (username or password) in your responses.** The script copies them to the clipboard — that is sufficient.
- Never log or store passwords in plain text
- Default to reader role unless write access is explicitly requested

If authentication fails, run `vault_login.sh <env>` first, then retry.

## Database Name Resolution

The scripts resolve the `<db-name>` argument in three stages:

**1. Exact match** — tries the name as-is under both Vault prefixes:
- `cdp-database/.../db-{name}` (customer project databases)
- `database/.../db-{name}` (platform/microservice databases)

**2. Environment suffix** — if no exact match, appends env-specific suffixes:

| Environment | Suffixes tried |
|---|---|
| staging | `-staging` |
| prod | `-stable`, `-beta` |
| sigma | `-sigma` |
| maestra | `-omega`, `-stable` |

So `analytics-settings` in maestra resolves to `analytics-settings-omega`.

**3. Fuzzy search** — if still not found, lists all configs via `vault list` and matches entries containing all dash-separated words from the input. Examples:
- `email-template-editor` → finds `email-template-visual-editor-stable` (all words match)
- If multiple matches, the script prints them and exits — specify the exact name

**You do not need to include the `db-` prefix** — the scripts add it automatically.

## Two Categories of Databases

**Customer databases** (`cdp-database/`): one per customer/tenant, no env suffix.
- Example: `test-maestra`, `jewellerybox`, `dodopizza`

**Platform databases** (`database/`): internal services, exist per environment with a suffix.
- Example: `mailings-stable`, `integrations-metadata-omega`, `email-scoring-staging`

When the user gives a service name without a suffix (e.g. "mailings"), the env suffix resolution handles it.

## Vault Path Convention

- Credentials: `cdp-database/creds/db-{role}-{name}` (fallback: `database/creds/...`)
- Config: `cdp-database/config/db-{name}` (fallback: `database/config/...`)
- Roles: `reader` (default), `writer`, `owner`
- Credentials expire after 12 hours

## Error Handling

**Token expired or missing:**
```bash
./scripts/vault_login.sh <env>
```

**Credentials path not found:**
- Scripts try exact name, env suffixes, then fuzzy search automatically
- If fuzzy search returns multiple matches, pick the right one and retry with the exact name

**Environment not recognized:**
- Valid environments: staging, prod, sigma, maestra
