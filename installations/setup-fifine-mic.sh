#!/usr/bin/env bash

# Installs the udev rule that pins the fifine mic's hardware capture gain (see
# udev/99-fifine-mic-gain.rules) and applies it to a mic that is already plugged in.

set -euo pipefail

sudo install -m 644 "$(dirname "$0")/../udev/99-fifine-mic-gain.rules" /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger --action=add --subsystem-match=sound --attr-match=idVendor=3142 || true
