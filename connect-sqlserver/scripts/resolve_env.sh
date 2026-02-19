#!/bin/bash
# Resolve environment to Vault address, Teleport proxy, and tsh binary
# Usage: eval "$(./resolve_env.sh <env>)"
# Environments: staging, prod, sigma, maestra

set -e

if [ -z "$1" ]; then
	echo "Error: Environment name required" >&2
	echo "Usage: $0 <staging|prod|sigma|maestra>" >&2
	exit 1
fi

ENV_NAME="$1"

case "$ENV_NAME" in
	staging)
		VAULT_ADDR="https://vault-staging.mindbox.ru/"
		TSH_PROXY="teleport.mindbox.ru"
		;;
	prod)
		VAULT_ADDR="https://vault.mindbox.ru/"
		TSH_PROXY="teleport.mindbox.ru"
		;;
	sigma)
		VAULT_ADDR="https://vault.s.mindbox.ru/"
		TSH_PROXY="teleport.mindbox.ru"
		;;
	maestra)
		VAULT_ADDR="https://vault.maestra.io/"
		TSH_PROXY="teleport.maestra.io"
		;;
	*)
		echo "Error: Unknown environment '$ENV_NAME'" >&2
		echo "Valid environments: staging, prod, sigma, maestra" >&2
		exit 1
		;;
esac

# Determine tsh binary and TELEPORT_HOME based on proxy
if [ "$TSH_PROXY" = "teleport.mindbox.ru" ]; then
	# RU environments use separate Teleport home and the Teleport Connect binary
	TSH_BIN=$(ls -d /Applications/Teleport\ Connect*/Contents/MacOS/tsh.app/Contents/MacOS/tsh 2>/dev/null | head -1)
	if [ -z "$TSH_BIN" ]; then
		echo "Error: Teleport Connect app not found in /Applications/" >&2
		exit 1
	fi
	TSH_TELEPORT_HOME="$HOME/.tshru"
else
	# Maestra uses system tsh
	TSH_BIN=$(command -v tsh 2>/dev/null)
	if [ -z "$TSH_BIN" ]; then
		echo "Error: tsh not found in PATH" >&2
		exit 1
	fi
	TSH_TELEPORT_HOME=""
fi

# Output eval-able variables
echo "export VAULT_ADDR='$VAULT_ADDR'"
echo "export TSH_BIN='$TSH_BIN'"
echo "export TSH_PROXY='$TSH_PROXY'"
echo "export TSH_TELEPORT_HOME='$TSH_TELEPORT_HOME'"
echo "export ENV_NAME='$ENV_NAME'"
