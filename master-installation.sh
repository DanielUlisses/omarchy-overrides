#!/bin/sh

. ./installations/install-stow.sh
. ./installations/install-slack.sh
. ./installations/install-teams-for-linux.sh
. ./installations/install-google-chrome.sh
. ./installations/install-vscode.sh

. ./installations/install-overrides.sh

. ./installations/global-uninstall.sh
. ./bin/run-cmd-stow.sh

hyprctl keyword monitor "eDP-1, disable"
hyprctl keyword monitor "DP-6, disable"
hyprctl keyword monitor "DP-6, enable"

echo "Omarchy overrides installation completed."