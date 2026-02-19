#!/bin/bash
# Ensure Teleport VNet is running (env-aware)
# Usage: ./ensure_vnet.sh
# Requires: TSH_BIN, TSH_PROXY, TSH_TELEPORT_HOME (from resolve_env.sh)

set -e

run_tsh() {
	if [ -n "$TSH_TELEPORT_HOME" ]; then
		TELEPORT_HOME="$TSH_TELEPORT_HOME" "$TSH_BIN" --proxy "$TSH_PROXY" "$@"
	else
		"$TSH_BIN" --proxy "$TSH_PROXY" "$@"
	fi
}

# Check if VNet is already running
if pgrep -f "tsh vnet" > /dev/null; then
	echo "tsh vnet is already running"
	exit 0
fi

# Check if logged in to Teleport
if ! run_tsh status > /dev/null 2>&1; then
	echo "Error: Not logged in to Teleport ($TSH_PROXY)" >&2
	if [ "$TSH_PROXY" = "teleport.mindbox.ru" ]; then
		echo "Please run: tshru login" >&2
	else
		echo "Please run: tsh login --proxy=$TSH_PROXY" >&2
	fi
	exit 1
fi

echo "Starting tsh vnet..."

# Start VNet in background
run_tsh vnet > /dev/null 2>&1 &

# Wait for VNet to initialize
sleep 3

# Verify it started
if pgrep -f "tsh vnet" > /dev/null; then
	echo "tsh vnet started successfully"
	exit 0
else
	echo "Error: Failed to start tsh vnet" >&2
	exit 1
fi
