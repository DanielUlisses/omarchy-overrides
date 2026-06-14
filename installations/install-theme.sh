#!/usr/bin/env bash

THEME_DIR="$HOME/.config/omarchy/themes/cyberpunk-reloaded"

if [ -d "$THEME_DIR" ]; then
  echo "Theme cyberpunk-reloaded already installed, skipping."
else
  echo "Installing cyberpunk-reloaded theme..."
  omarchy theme install https://github.com/DanielUlisses/omarchy-cyberpunk-reloaded-theme.git
fi
