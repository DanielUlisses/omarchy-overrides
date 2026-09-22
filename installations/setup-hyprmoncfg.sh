#!/usr/bin/env bash

# Runs after bin/run-cmd-stow.sh has linked the profiles. `manage` adds hyprmoncfg's
# block to the end of hyprland.lua (below the overrides dofile); the daemon then picks
# the saved profile matching the connected monitors.

set -euo pipefail

hyprmoncfg manage
systemctl --user enable --now hyprmoncfgd.service
hyprmoncfg doctor || echo "WARNING: hyprmoncfg doctor reported a problem, see above." >&2
