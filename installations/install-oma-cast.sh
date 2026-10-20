#!/usr/bin/env bash

# oma-cast: a Raycast-style launcher that runs as an omarchy-shell plugin, put on
# SUPER+SPACE in place of Omarchy's app launcher (overrides/omarchy-overrides.lua binds it
# once the plugin is linked). https://github.com/typecraft-dev/oma-cast
#
# It needs Omarchy 4.5's shell (ShellIpc, Style.space, shell.env/iconPath); on 4.0 it fails
# to load. Until then this only keeps the clone ready and skips the install, and
# SUPER+SPACE stays Omarchy's launcher. Rerun it after updating Omarchy.
#
# The clone lives in ~/.local/share/oma-cast: the plugin is a symlink into it, so it must
# stay put. Needs a running Omarchy session (the install talks to omarchy-shell).

set -euo pipefail

REPO="https://github.com/typecraft-dev/oma-cast.git"
DIR="$HOME/.local/share/oma-cast"
SHELL_DIR="${OMARCHY_PATH:-/usr/share/omarchy}/shell"

if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull -q --ff-only || echo "WARNING: could not update $DIR" >&2
else
  git clone -q "$REPO" "$DIR"
fi

if [ ! -f "$SHELL_DIR/Commons/ShellIpc.qml" ]; then
  echo "oma-cast needs Omarchy 4.5 (no ShellIpc in $SHELL_DIR); skipped, SUPER+SPACE stays Omarchy's launcher."
  exit 0
fi

"$DIR/bin/oma-cast" install
hyprctl reload >/dev/null # pick up the SUPER+SPACE binding now that the plugin is linked
echo "oma-cast installed on SUPER+SPACE."
