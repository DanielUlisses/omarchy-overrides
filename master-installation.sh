#!/bin/sh

. ./installations/install-stow.sh
. ./installations/install-slack.sh
. ./installations/install-teams-for-linux.sh
. ./installations/install-google-chrome.sh
. ./installations/install-vscode.sh

. ./installations/install-overrides.sh

. ./installations/global-uninstall.sh
. ./bin/run-cmd-stow.sh

echo "Omarchy overrides installation completed."