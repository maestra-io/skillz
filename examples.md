# Usage Examples

## Example 1: Simple Connection (Read-Only)

**User request:**
"Connect to nexus database"

**Agent actions:**

1. Find database:
```bash
./scripts/find_db.sh nexus
# Output: db-nexus-omega.teleport.maestra.io
```

2. Ensure vnet:
```bash
./scripts/ensure_vnet.sh
# Output: tsh vnet is already running (or starts it)
```

3. Verify connectivity:
```bash
ping -c 2 db-nexus-omega.teleport.maestra.io
# Should respond with vnet IP range (100.x.x.x)
```

4. Get credentials:
```bash
./scripts/get_vault_creds.sh nexus-omega reader
# Output: v-token-db-reader-nexus-omega-AbCd123 <password>
```

5. Launch DBeaver:
```bash
./scripts/launch_dbeaver.sh db-nexus-omega.teleport.maestra.io nexus v-token-db-reader-nexus-omega-AbCd123 <password>
```

---

## Example 2: Write Access

**User request:**
"Connect to nexus with write access"

**Agent actions:**

Same steps as Example 1, but use `writer` role:

```bash
./scripts/get_vault_creds.sh nexus-omega writer
```

---

## Example 3: Owner Access

**User request:**
"Connect to nexus as owner"

**Agent actions:**

Same steps as Example 1, but use `owner` role:

```bash
./scripts/get_vault_creds.sh nexus-omega owner
```

---

## Example 4: User Already Specifies Full Name

**User request:**
"Connect to db-nexus-omega"

**Agent actions:**

The scripts handle both formats automatically:

```bash
./scripts/find_db.sh db-nexus-omega
# Output: db-nexus-omega.teleport.maestra.io
```

---

## Example 5: Complete Workflow (Automated)

Here's a complete bash script combining all steps:

```bash
#!/bin/bash
# connect_db.sh - Complete connection workflow
# Usage: ./connect_db.sh <db-name> [reader|writer|owner]

DB_NAME="$1"
ROLE="${2:-reader}"

echo "🔍 Finding database..."
HOSTNAME=$(./scripts/find_db.sh "$DB_NAME")
echo "✓ Found: $HOSTNAME"

echo "🌐 Ensuring vnet is running..."
./scripts/ensure_vnet.sh

echo "🏓 Verifying connectivity..."
if ping -c 2 "$HOSTNAME" > /dev/null 2>&1; then
    echo "✓ Database is reachable"
else
    echo "✗ Warning: Database not reachable via ping"
fi

echo "🔑 Getting credentials from Vault..."
read USERNAME PASSWORD <<< $(./scripts/get_vault_creds.sh "$HOSTNAME" "$ROLE")
echo "✓ Credentials retrieved: $USERNAME"

# Extract database name from hostname
DB_CLEAN=$(echo "$HOSTNAME" | sed 's/db-//' | sed 's/-.*//')

echo "🚀 Launching DBeaver..."
./scripts/launch_dbeaver.sh "$HOSTNAME" "$DB_CLEAN" "$USERNAME" "$PASSWORD"
```

---

## Common Issues and Solutions

### Issue 1: Database Not Found

**Error:**
```
Error: Database 'nexus' not found in Teleport apps
```

**Solution:**
Check available databases:
```bash
tsh app ls | grep "^db-"
```

Ensure you're logged in:
```bash
tsh status
tsh login --proxy=teleport.maestra.io
```

### Issue 2: Vnet Won't Start

**Error:**
```
Error: Failed to start tsh vnet
```

**Solution:**
Check authentication:
```bash
tsh status
```

Re-login if needed:
```bash
tsh login --proxy=teleport.maestra.io
```

### Issue 3: Vault Credentials Failed

**Error:**
```
Error: Failed to retrieve credentials from Vault
```

**Solution:**
Check Vault authentication:
```bash
vault token lookup
```

Login to Vault if needed:
```bash
vault login -method=oidc
```

Try different role:
```bash
# Instead of 'writer', try 'reader'
./scripts/get_vault_creds.sh nexus-omega reader
```

### Issue 4: Connection Times Out

**Problem:**
DBeaver can't connect to the database.

**Solution:**
1. Verify vnet is routing correctly:
```bash
ping db-nexus-omega.teleport.maestra.io
# Should show 100.x.x.x IP range
```

2. Check tsh status:
```bash
tsh status
```

3. Restart vnet:
```bash
pkill -f "tsh vnet"
tsh vnet &
sleep 3
```

---

## Testing the Skill

To test if the skill is working:

1. **Test database discovery:**
```bash
./scripts/find_db.sh nexus
```

2. **Test vnet:**
```bash
./scripts/ensure_vnet.sh
pgrep -f "tsh vnet"
```

3. **Test vault access:**
```bash
./scripts/get_vault_creds.sh nexus-omega reader
```

4. **Test full workflow:**
```bash
# Run the complete workflow for a test database
DB=$(./scripts/find_db.sh nexus)
./scripts/ensure_vnet.sh
ping -c 2 "$DB"
read USER PASS <<< $(./scripts/get_vault_creds.sh nexus-omega reader)
echo "Credentials: $USER (password hidden)"
```
