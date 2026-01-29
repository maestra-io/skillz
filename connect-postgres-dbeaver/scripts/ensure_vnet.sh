#!/bin/bash
# Ensure Teleport vnet is running
# Usage: ./ensure_vnet.sh

set -e

# Check if vnet is already running
if pgrep -f "tsh vnet" > /dev/null; then
    echo "tsh vnet is already running"
    exit 0
fi

# Check if logged in to Teleport
if ! tsh --proxy=teleport.maestra.io status > /dev/null 2>&1; then
    echo "Error: Not logged in to Teleport" >&2
    echo "Please run: tsh login --proxy=teleport.maestra.io" >&2
    exit 1
fi

echo "Starting tsh vnet..."

# Start vnet in background with proper proxy
tsh vnet --proxy=teleport.maestra.io > /dev/null 2>&1 &

# Wait for vnet to initialize
sleep 3

# Verify it started
if pgrep -f "tsh vnet" > /dev/null; then
    echo "tsh vnet started successfully"
    exit 0
else
    echo "Error: Failed to start tsh vnet" >&2
    echo "Check authentication with: tsh --proxy=teleport.maestra.io status" >&2
    exit 1
fi
