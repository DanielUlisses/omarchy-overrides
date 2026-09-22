#!/usr/bin/env bash

# Remmina (Pythian cloud PC), Solaar (Logitech devices) and Claude Desktop.

set -euo pipefail

# The -git builds match what bin/omarchy-context was tuned against. `pacman -Q` also
# matches providers, so a machine that already has the repo remmina/freerdp keeps them
# instead of hitting a package conflict under --noconfirm.
echo "Installing Remmina..."
pacman -Q freerdp >/dev/null 2>&1 || yay -S --noconfirm freerdp-git
pacman -Q remmina >/dev/null 2>&1 || yay -S --noconfirm remmina-git

echo "Installing Solaar..."
yay -S --noconfirm --needed solaar

echo "Installing Claude Desktop..."
yay -S --noconfirm --needed claude-desktop

if [ ! -f "$HOME/.local/share/remmina/group_rdp_pythian_172-16-0-16.remmina" ]; then
  echo "NOTE: the Pythian Remmina profile is missing; SUPER+SHIFT+R and context 1 expect" >&2
  echo "      ~/.local/share/remmina/group_rdp_pythian_172-16-0-16.remmina (recreate it in Remmina)." >&2
fi
