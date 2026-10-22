#!/usr/bin/env bash

# Dynamic Island settings that differ from the plugin's defaults. They live in
# ~/.config/omarchy/shell.json, which is not in the repo (other plugins keep secrets
# there), so they are applied here. Runs after setup-hyprmoncfg.sh: the main monitor is
# whichever one hyprmoncfg pins workspace 1 to.
#   monitor       the island's default "primary" matches no output, so it fell back to
#                 the laptop; it only takes a connector name, and those swap per machine
#   reserveSpace  false: float over windows instead of shrinking them
#   secretaryPath, chatWorkspace, chatModel
#                 Island Chat (SUPER+A) starts in the secretary repo on Sonnet
# Its font is set by apply-fonts.sh, with everything else.
# Calendars are not set here: the .ics links are secret. Add them in the island (calendar
# › settings button: paste a link, label, colour, Chrome profile per calendar); they are
# kept in ~/.config/omarchy/dynamic-island/{calendars,prefs}.json -- copy that folder
# over from another machine to bring them along.

set -euo pipefail

SHELL_JSON="$HOME/.config/omarchy/shell.json"
jq -e '.plugins[]? | select(.id=="omarchy-dynamic-island")' "$SHELL_JSON" >/dev/null 2>&1 || {
  echo "Dynamic Island not installed, skipping."
  exit 0
}

target=$(hyprctl workspacerules -j 2>/dev/null | jq -r 'first(.[]|select(.workspaceString=="1")|.monitor // empty)')
case "$target" in
desc:*) main=$(hyprctl monitors -j | jq -r --arg d "${target#desc:}" 'first(.[]|select(.description==$d)|.name) // empty') ;;
*) main="$target" ;;
esac
main=${main:-focused} # no rule yet: follow focus rather than pick the laptop

tmp=$(mktemp)
jq --arg m "$main" '(.plugins[] | select(.id=="omarchy-dynamic-island")) |= (.monitor = $m | .reserveSpace = false
  | .secretaryPath = "~/repos/daniel/secretary" | .chatWorkspace = "secretary" | .chatModel = "claude-sonnet-5-5")' \
  "$SHELL_JSON" >"$tmp" && mv "$tmp" "$SHELL_JSON"
echo "Dynamic Island on $main, floating over windows; Island Chat starts in Secretary on Sonnet."

# A live shell.json reload can leave the bar half-drawn; a clean restart does not.
omarchy restart shell >/dev/null 2>&1 || true
