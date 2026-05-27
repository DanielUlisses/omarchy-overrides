#!/bin/sh

set -e

HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.lua"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERRIDES_CONFIG="$OVERRIDES_DIR/overrides/omarchy-overrides.lua"
SOURCE_LINE="dofile(\"$OVERRIDES_CONFIG\")"

if [ ! -f "$HYPRLAND_CONFIG" ]; then
    echo "Hyprland configuration file not found at $HYPRLAND_CONFIG"
    echo "Please ensure Hyprland is installed and configured."
    exit 1
fi

if [ ! -f "$OVERRIDES_CONFIG" ]; then
    echo "Overrides configuration file not found at $OVERRIDES_CONFIG"
    echo "Please ensure the overrides file is present."
    exit 1
fi

if grep -Fxq "$SOURCE_LINE" "$HYPRLAND_CONFIG"; then
    echo "Overrides already sourced in hyprland.lua"
else
    printf '\n%s\n' "$SOURCE_LINE" >> "$HYPRLAND_CONFIG"
    echo "Overrides sourced successfully in hyprland.lua"
fi

echo "Installation of Hyprland overrides completed."
