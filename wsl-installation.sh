#!/usr/bin/env bash

# WSL (Arch) counterpart of master-installation.sh: the Omarchy shell experience only --
# no Hyprland, GUI apps, keybinds, plugins or monitor profiles.

set -euo pipefail

cd "$(dirname "$0")"

bash ./installations/link-overrides-repo.sh
sudo bash ./installations/wsl-install-packages.sh
bash ./installations/wsl-setup-shell.sh
bash ./bin/run-cmd-stow.sh

echo "WSL installation completed. Open a new shell."
