#!/usr/bin/env bash

# Install claude-acc (Claude Code account switcher) into ~/.claude-switch/bin.
# `claude-acc install` is not used: it appends shell integration to ~/.bashrc, which is
# stowed from this repo and already has the init line.

set -euo pipefail

BIN="$HOME/.claude-switch/bin/claude-acc"

if [ -x "$BIN" ]; then
  echo "claude-acc already installed, skipping."
  exit 0
fi

echo "Installing claude-acc..."
mkdir -p "$(dirname "$BIN")"
curl -fsSL -o "$BIN" \
  "https://github.com/Nemo-Illusionist/claude-code-account-switcher/releases/latest/download/claude-acc-linux-$(uname -m)"
chmod +x "$BIN"
