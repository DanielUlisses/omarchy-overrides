#!/usr/bin/env bash

# One font everywhere: the system monospace font, which the lock screen (lock-explorer's
# designs use the shell's Style.font.family = "monospace") already follows. Runs LAST in
# master-installation.sh, because the Tsukiyo extras patch the bar to a fixed
# "Adwaita Sans" and the Dynamic Island ships with its own font -- this puts both back.
# Safe to rerun any time, e.g. after `install-extras.sh` or a theme update.

set -euo pipefail

FONT="JetBrainsMono Nerd Font"

[ "$(omarchy font current 2>/dev/null)" = "$FONT" ] || omarchy font set "$FONT"

# Bar (and the clock, which takes the bar's family): follow the system font again,
# as the stock bar does, instead of a hard-coded family.
BAR="$HOME/.config/omarchy/plugins/$USER.bar/Bar.qml"
if [ -f "$BAR" ]; then
  sed -i -E 's|^(  property string fontFamily: ).*|\1Style.font.family|' "$BAR"
  echo "Bar font follows the system font."
fi

# Dynamic Island, when installed: its font is a plugin setting in shell.json.
SHELL_JSON="$HOME/.config/omarchy/shell.json"
if [ -f "$SHELL_JSON" ] && jq -e '.plugins[]? | select(.id=="omarchy-dynamic-island")' "$SHELL_JSON" >/dev/null; then
  tmp=$(mktemp)
  jq --arg f "$FONT" '(.plugins[] | select(.id=="omarchy-dynamic-island") | .textFont) = $f' "$SHELL_JSON" >"$tmp" &&
    mv "$tmp" "$SHELL_JSON"
  echo "Dynamic Island font set to $FONT."
fi

# A live shell.json reload can leave the bar half-drawn; a clean restart does not.
omarchy restart shell >/dev/null 2>&1 || true
