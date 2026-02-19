# vault-helpers

Standalone Vault helpers for Mindbox/Maestra environments. Provides scripts for environment switching, OIDC login, and database credential retrieval.

## Scripts

All scripts are in `scripts/`.

| Script | Usage | Output |
|--------|-------|--------|
| `resolve_env.sh <env>` | Resolve env to Vault/Teleport vars | eval-able exports |
| `vault_login.sh <env>` | OIDC login + save token | Token saved |
| `vault_creds.sh <env> <db> [role]` | Get DB credentials | `username password` |
| `vault_config.sh <env> <db>` | Get DB connection config | `host database driver` |

## Environments

| Name | Vault Address |
|------|--------------|
| staging | `https://vault-staging.mindbox.ru/` |
| prod | `https://vault.mindbox.ru/` |
| sigma | `https://vault.s.mindbox.ru/` |
| maestra | `https://vault.maestra.io/` |

## Token Storage

Tokens are cached per-environment in `~/.vault-tokens/`. The scripts load cached tokens automatically — no re-authentication needed until they expire.
