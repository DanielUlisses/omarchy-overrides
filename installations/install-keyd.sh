#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

SOURCE_CONFIG="${REPO_ROOT}/resources/keyd/etc/keyd/default.conf"
TARGET_CONFIG="/etc/keyd/default.conf"

if [[ ! -f "${SOURCE_CONFIG}" ]]; then
  echo "Missing keyd config source: ${SOURCE_CONFIG}" >&2
  exit 1
fi

echo "Installing keyd..."
if ! command -v keyd >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm keyd
fi

sudo install -d -m 755 /etc/keyd
sudo install -m 644 "${SOURCE_CONFIG}" "${TARGET_CONFIG}"

sudo systemctl enable --now keyd.service
sudo systemctl restart keyd.service

echo "keyd installed/configured: ${TARGET_CONFIG}"
