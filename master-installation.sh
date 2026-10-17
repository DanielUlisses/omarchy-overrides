#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

bash ./installations/link-overrides-repo.sh

# Each step runs as its own process so one script's `exit`/variables can't leak into the next.
bash ./installations/install-stow.sh
bash ./installations/install-slack.sh
bash ./installations/install-teams-for-linux.sh
bash ./installations/install-google-chrome.sh
bash ./installations/install-vscode.sh
bash ./installations/install-herdr.sh
bash ./installations/install-apps.sh
bash ./installations/setup-cloudpc.sh

bash ./installations/install-overrides.sh
bash ./installations/install-theme.sh
bash ./installations/install-claude-acc.sh
bash ./installations/install-plugins.sh

bash ./installations/global-uninstall.sh
bash ./bin/run-cmd-stow.sh
bash ./installations/setup-hyprmoncfg.sh
bash ./installations/configure-dynamic-island.sh

# Last: the theme extras and plugins above set their own fonts; this puts one font back everywhere.
bash ./installations/apply-fonts.sh

echo "Omarchy overrides installation completed."
