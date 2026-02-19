#!/bin/bash
# Login to Vault via OIDC and save per-env token
# Usage: ./vault_login.sh <env>
# Environments: staging, prod, sigma, maestra

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$1" ]; then
	echo "Error: Environment name required" >&2
	echo "Usage: $0 <staging|prod|sigma|maestra>" >&2
	exit 1
fi

ENV_NAME="$1"

# Resolve environment
eval "$("$SCRIPT_DIR/resolve_env.sh" "$ENV_NAME")"

# Unset existing token so OIDC login starts fresh
unset VAULT_TOKEN

echo "Logging in to Vault at $VAULT_ADDR ..." >&2
vault login -method=oidc || { echo "Vault login failed" >&2; exit 1; }

# Save token for this environment
mkdir -p "$HOME/.vault-tokens"
chmod 700 "$HOME/.vault-tokens"
cp "$HOME/.vault-token" "$HOME/.vault-tokens/$ENV_NAME"
chmod 600 "$HOME/.vault-tokens/$ENV_NAME"

VAULT_TOKEN=$(cat "$HOME/.vault-token")
export VAULT_TOKEN
echo "Token saved for $ENV_NAME" >&2
