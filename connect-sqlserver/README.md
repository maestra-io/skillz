# SQL Server Connection Skill

Cursor/Claude Code skill for automated SQL Server database connections via `sqlcmd` using Teleport and Vault across multiple environments.

## Overview

This skill automates the complete workflow for connecting to SQL Server databases:
- Resolves environment (staging, prod, sigma, maestra) to correct Vault and Teleport endpoints
- Discovers databases in Teleport
- Manages Teleport VNet connectivity
- Retrieves dynamic credentials from Vault
- Outputs connection details for `sqlcmd` execution

## Prerequisites

Required tools:
- [Teleport client (`tsh`)](https://goteleport.com/download/)
- [Vault CLI](https://www.vaultproject.io/downloads)
- [sqlcmd](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility)
- `jq` - JSON processor

Install on MacOS:
```bash
brew install teleport vault sqlcmd jq
```

## Usage

### Via Cursor/Claude Code

Ask the AI to connect to a database:

```
"Connect to test-maestra in maestra env"
"Query the Staff table in test-maestra (maestra)"
"Connect to my-db in prod with write access"
```

### Via Command Line

```bash
cd scripts/
./connect.sh <database-name> <environment> [reader|writer|owner]
```

**Examples:**
```bash
./connect.sh test-maestra maestra          # Read-only (default)
./connect.sh test-maestra maestra writer   # Read/write
./connect.sh my-database prod owner        # Full admin access
```

## Environments

| Name | Vault | Teleport Proxy |
|------|-------|----------------|
| staging | vault-staging.mindbox.ru | teleport.mindbox.ru |
| prod | vault.mindbox.ru | teleport.mindbox.ru |
| sigma | vault.s.mindbox.ru | teleport.mindbox.ru |
| maestra | vault.maestra.io | teleport.maestra.io |

## Structure

```
connect-sqlserver/
├── SKILL.md                  # AI instructions
├── README.md                 # This file
└── scripts/
    ├── connect.sh            # Main automated workflow
    ├── resolve_env.sh        # Environment resolution
    ├── find_db.sh            # Database discovery via Teleport
    ├── ensure_vnet.sh        # VNet management
    ├── get_vault_config.sh   # Connection config from Vault
    └── get_vault_creds.sh    # Credential retrieval from Vault
```

## License

Internal use for Maestra.io organization.
