#!/usr/bin/env bash

THEME_DIR="$HOME/.config/omarchy/themes/cyberpunk-reloaded"

if [ -d "$THEME_DIR" ]; then
  echo "Theme cyberpunk-reloaded already installed, skipping."
else
  echo "Installing cyberpunk-reloaded theme..."
  omarchy theme install https://github.com/DanielUlisses/omarchy-cyberpunk-reloaded-theme.git
fi

# omarchy-theme-set-vscode only knows marketplace extensions or its generated "Omarchy"
# theme, so install the .vsix the theme ships and select it ourselves.
SETTINGS="$HOME/.config/Code/User/settings.json"
if command -v code >/dev/null 2>&1; then
  code --install-extension "$THEME_DIR"/vscode-extension/*.vsix --force
  [ -f "$SETTINGS" ] || printf '{\n}\n' > "$SETTINGS"
  grep -q '"workbench.colorTheme"' "$SETTINGS" ||
    sed -i --follow-symlinks -E '0,/\{/{s/\{/{ "workbench.colorTheme": "",/}' "$SETTINGS"
  sed -i --follow-symlinks -E \
    's|("workbench.colorTheme"[[:space:]]*:[[:space:]]*")[^"]*(")|\1Cyberpunk Reloaded\2|' "$SETTINGS"
fi
