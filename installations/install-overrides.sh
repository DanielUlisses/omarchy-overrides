#!/bin/sh

set -e

HYPERLAND_CONFIG="$HOME/.config/hyperland/hyperland.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDES_CONFIG="$SCRIPT_DIR/../overrides/omarchy-overrides.conf"
SOURCE_LINE="source = $OVERRIDES_CONFIG"

# Check if hyperland.conf exists
if [ ! -f "$HYPERLAND_CONFIG" ]; then
    echo "Hyperland configuration file not found at $HYPERLAND_CONFIG"
    echo "Please ensure Hyperland is installed and configured."
    exit 1
fi

# check if overides config exists
if [ ! -f "$OVERRIDES_CONFIG" ]; then
    echo "Overrides configuration file not found at $OVERRIDES_CONFIG"
    echo "Please ensure the overrides file is present."
    exit 1
fi

# Check if the source line already exists in hyperland.conf
if grep -Fxq "$SOURCE_LINE" "$HYPERLAND_CONFIG"; then
    echo "Overrides already sourced in hyperland.conf"
else
    # Append the source line to hyperland.conf
    echo "" >> "$HYPERLAND_CONFIG"
    echo "$SOURCE_LINE" >> "$HYPERLAND_CONFIG"
    echo "Overrides sourced successfully in hyperland.conf"
fi

echo "Installation of Hyperland overrides completed."
