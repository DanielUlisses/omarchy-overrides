#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/HANCORE-linux/waybar-themes.git"
TMP_DIR="$(mktemp -d)"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

git clone --depth=1 "$REPO_URL" "$TMP_DIR"
mkdir -p "$HOME/.config/waybar"
cp -rf "$TMP_DIR/config/V3/." "$HOME/.config/waybar"

omarchy-restart-waybar