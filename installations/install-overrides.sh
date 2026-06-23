#!/bin/sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERRIDES_LUA="$OVERRIDES_DIR/overrides/omarchy-overrides.lua"
OVERRIDES_CONF="$OVERRIDES_DIR/overrides/omarchy-overrides.conf"

HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"

if [ -f "$HYPRLAND_LUA" ]; then
    if [ ! -f "$OVERRIDES_LUA" ]; then
        echo "Overrides Lua file not found at $OVERRIDES_LUA"
        exit 1
    fi
    SOURCE_LINE="dofile(\"$OVERRIDES_LUA\")"
    if grep -Fxq "$SOURCE_LINE" "$HYPRLAND_LUA"; then
        echo "Overrides already sourced in hyprland.lua"
    else
        printf '\n%s\n' "$SOURCE_LINE" >> "$HYPRLAND_LUA"
        echo "Overrides sourced successfully in hyprland.lua"
    fi
elif [ -f "$HYPRLAND_CONF" ]; then
    if [ ! -f "$OVERRIDES_CONF" ]; then
        echo "Overrides conf file not found at $OVERRIDES_CONF"
        exit 1
    fi
    SOURCE_LINE="source = $OVERRIDES_CONF"
    if grep -Fxq "$SOURCE_LINE" "$HYPRLAND_CONF"; then
        echo "Overrides already sourced in hyprland.conf"
    else
        printf '\n%s\n' "$SOURCE_LINE" >> "$HYPRLAND_CONF"
        echo "Overrides sourced successfully in hyprland.conf"
    fi
else
    echo "No Hyprland configuration file found (checked hyprland.lua and hyprland.conf)"
    echo "Please ensure Hyprland is installed and configured."
    exit 1
fi

echo "Installation of Hyprland overrides completed."
