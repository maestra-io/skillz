# Quick Start Guide

Connect to PostgreSQL databases via DBeaver in 3 simple ways:

## 1. Ask AI (Easiest)

In Cursor or Claude Code, simply say:

```
"Подключись к базе nexus"
"Connect to nexus with write access"
```

The AI will run all steps automatically.

## 2. One Command (Fast)

```bash
cd .cursor/skills/connect-postgres-dbeaver/scripts
./connect.sh nexus
```

That's it! DBeaver will open with an active connection.

## 3. Step by Step (Manual)

If you need to run steps separately:

```bash
# Find database
./find_db.sh nexus
# Output: db-nexus-omega.teleport.maestra.io

# Ensure VNet is running
./ensure_vnet.sh

# Get credentials
./get_vault_creds.sh nexus-omega reader
# Output: username password

# Launch DBeaver
./launch_dbeaver.sh db-nexus-omega.teleport.maestra.io nexus <username> <password>
```

## Access Levels

```bash
./connect.sh nexus           # Read-only (default)
./connect.sh nexus writer    # Read + Write
./connect.sh nexus owner     # Full admin
```

## Prerequisites

Install once:

```bash
brew install teleport vault dbeaver-community jq
```

Authenticate once (valid for hours):

```bash
tsh login --proxy=teleport.maestra.io
vault login -method=oidc
```

## Troubleshooting

**Password prompt in DBeaver?**
→ Close DBeaver, run script again

**Database not found?**
→ `tsh --proxy=teleport.maestra.io app ls | grep db-`

**Need help?**
→ See [README.md](README.md) or [SKILL.md](SKILL.md)

## What Happens Automatically

✅ Checks if tools are installed  
✅ Finds database in Teleport  
✅ Starts VNet if needed  
✅ Verifies connectivity  
✅ Gets fresh credentials (12h TTL)  
✅ Launches DBeaver with saved password  
✅ Auto-connects to database  

No manual password entry. No configuration files to edit. Just works.
