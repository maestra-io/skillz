# linqpad-connection

Automates LINQPad database connections for Mindbox/Maestra environments. Uses [vault-helpers](../vault-helpers/) for Vault operations, then configures ConnectionsV2.xml and macOS Keychain.

## Script

| Script | Usage | Output |
|--------|-------|--------|
| `linqpad_connect.sh <env> <db> [role]` | Full LINQPad connection setup | Connection ready |

## Dependencies

- `~/Git/Mindbox/skillz/vault-helpers/` — Vault credential and config retrieval
