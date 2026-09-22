#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERRIDES_LUA="$OVERRIDES_DIR/overrides/omarchy-overrides.lua"
OVERRIDES_CONF="$OVERRIDES_DIR/overrides/omarchy-overrides.conf"

HYPRLAND_LUA="$HOME/.config/hypr/hyprland.lua"
HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"

# hyprmoncfg appends its own block to hyprland.lua and expects it to load last, so the
# overrides have to go in above it rather than at the end of the file.
HYPRMONCFG_MARKER="-- Added by hyprmoncfg:"

if [ -f "$HYPRLAND_LUA" ]; then
    if [ ! -f "$OVERRIDES_LUA" ]; then
        echo "Overrides Lua file not found at $OVERRIDES_LUA"
        exit 1
    fi
    SOURCE_LINE="dofile(\"$OVERRIDES_LUA\")"
    if grep -Fxq "$SOURCE_LINE" "$HYPRLAND_LUA"; then
        echo "Overrides already sourced in hyprland.lua"
    elif grep -Fq -e "$HYPRMONCFG_MARKER" "$HYPRLAND_LUA"; then
        awk -v line="$SOURCE_LINE" -v marker="$HYPRMONCFG_MARKER" '
            !done && index($0, marker) == 1 { print line; print ""; done = 1 }
            { print }
        ' "$HYPRLAND_LUA" > "$HYPRLAND_LUA.tmp"
        cat "$HYPRLAND_LUA.tmp" > "$HYPRLAND_LUA" # rewrite in place, keeping a symlinked hyprland.lua intact
        rm "$HYPRLAND_LUA.tmp"
        echo "Overrides sourced successfully in hyprland.lua (above hyprmoncfg)"
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
