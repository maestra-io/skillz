# PostgreSQL DBeaver Connection Skill

Cursor/Claude Code skill for automated PostgreSQL database connections via DBeaver using Teleport and Vault.

## Overview

This skill automates the complete workflow for connecting to PostgreSQL databases:
- 🔍 Discovers databases in Teleport
- 🌐 Manages Teleport VNet connectivity  
- 🔑 Retrieves dynamic credentials from Vault
- 🚀 Launches DBeaver with connection parameters

## Installation

### For Cursor IDE

```bash
# Clone to project skills directory
cd .cursor/skills/
git clone https://github.com/maestra-io/skillz.git connect-postgres-dbeaver
```

### For Claude Code

```bash
# Clone to appropriate skills directory
git clone https://github.com/maestra-io/skillz.git connect-postgres-dbeaver
```

## Prerequisites

Required tools:
- [Teleport client (`tsh`)](https://goteleport.com/download/)
- [Vault CLI](https://www.vaultproject.io/downloads)
- [DBeaver](https://dbeaver.io/download/)
- `jq` - JSON processor

Install on MacOS:
```bash
brew install teleport vault dbeaver-community jq
```

## Authentication Setup

Before using this skill, ensure you're authenticated:

```bash
# Teleport
tsh login --proxy=teleport.maestra.io

# Vault
vault login -method=oidc
```

## Usage

### Via Cursor/Claude Code

Simply ask the AI to connect to a database:

```
"Подключись к базе nexus"
"Connect to nexus database"
"Connect to nexus with write access"
"Connect to staging as owner"
```

### Via Command Line

Use the automated connection script:

```bash
cd .cursor/skills/connect-postgres-dbeaver/scripts
./connect.sh <database-name> [reader|writer|owner]
```

**Examples:**
```bash
./connect.sh nexus              # Read-only (default)
./connect.sh nexus writer       # Read/write
./connect.sh nexus owner        # Full admin access
```

The skill automatically:
1. ✅ Checks all prerequisites (tsh, vault, dbeaver, jq)
2. ✅ Finds the database in Teleport
3. ✅ Starts VNet if needed
4. ✅ Verifies network connectivity
5. ✅ Gets fresh credentials from Vault
6. ✅ Launches DBeaver with saved password
7. ✅ Auto-connects to the database

## Access Roles

Three levels of database access:

| Role | Access Level | Use Case |
|------|-------------|----------|
| `reader` | Read-only | Default - querying data |
| `writer` | Read/Write | Data modifications |
| `owner` | Full access | Schema changes, admin tasks |

## Examples

See [examples.md](examples.md) for detailed usage scenarios.

## Structure

```
connect-postgres-dbeaver/
├── SKILL.md                  # Main skill instructions for AI
├── README.md                 # This file
├── examples.md               # Usage examples
└── scripts/
    ├── connect.sh            # 🎯 Main automated workflow
    ├── find_db.sh            # Database discovery via Teleport
    ├── ensure_vnet.sh        # VNet management
    ├── get_vault_creds.sh    # Credential retrieval from Vault
    ├── launch_dbeaver.sh     # DBeaver launcher with password saving
    └── cleanup_connections.sh # Clean up broken connections
```

## Troubleshooting

### Password prompt appears in DBeaver

**Problem:** DBeaver shows "SCRAM authentication - no password provided"

**Solution:** Close DBeaver and run the script again. It will fetch fresh credentials and properly save the password.

```bash
killall DBeaver
./scripts/connect.sh nexus
```

### Teleport version warning

**Problem:** Warning about incompatible tsh client/server versions

**Solution:** Already handled automatically by scripts using `--proxy=teleport.maestra.io`

### Multiple Teleport profiles

**Problem:** "Active profile expired" or wrong cluster

**Solution:**
```bash
# Check which profile is active
tsh status

# Scripts automatically use correct proxy
tsh --proxy=teleport.maestra.io status
```

### Vault connection refused

**Problem:** `dial tcp 127.0.0.1:8200: connect: connection refused`

**Solution:** Set VAULT_ADDR (scripts do this automatically)
```bash
export VAULT_ADDR=https://vault.maestra.io
vault token lookup
```

### Database not found
```bash
# List available databases
tsh --proxy=teleport.maestra.io app ls | grep "^db-"

# Check authentication
tsh --proxy=teleport.maestra.io status
```

### VNet not starting
```bash
# Check VNet status
pgrep -f "tsh vnet"

# Kill and restart
pkill -f "tsh vnet"
tsh vnet --proxy=teleport.maestra.io &
sleep 3
```

### Clean up broken connections

If you have old broken connections in DBeaver:

```bash
./scripts/cleanup_connections.sh
```

### Expired credentials

**Problem:** Connection stops working after some time

**Solution:** Credentials expire after 12 hours. Just reconnect:
```bash
./scripts/connect.sh nexus
```

## Security

- All credentials are dynamic with automatic TTL expiration
- Passwords are never stored or logged
- Read-only access (`reader`) is the default
- Credentials expire after ~1 hour

## Contributing

1. Test changes locally first
2. Ensure scripts remain portable (bash compatible)
3. Keep SKILL.md under 500 lines
4. Add examples for new features

## License

Internal use for Maestra.io organization.

## Support

For issues or questions, contact the platform team or open an issue in the repository.
