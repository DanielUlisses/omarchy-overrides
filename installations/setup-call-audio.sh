#!/usr/bin/env bash

# Makes WirePlumber follow wireplumber/.config/wireplumber/wireplumber.conf.d/ (linked by
# bin/run-cmd-stow.sh). Settings saved in ~/.local/state/wireplumber/sm-settings beat the
# conf files, and this machine has all of them saved (node.restore-default-targets=true
# among them), so the conf alone changes nothing. Manual default picks are dropped too,
# so the priorities decide which mic and speaker a call gets.
# Restarts WirePlumber: audio drops for a second, and apps in a call may need to rejoin.

set -euo pipefail

wpctl settings --delete
wpctl clear-default
sleep 2 # WirePlumber writes its state file on a timer; restarting sooner loses the delete
systemctl --user restart wireplumber
sleep 2

bash "$(dirname "$0")/../bin/omarchy-call-audio" || true
