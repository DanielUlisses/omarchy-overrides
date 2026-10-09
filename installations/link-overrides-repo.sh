#!/usr/bin/env bash

# Point ~/.omarchy-overrides at this repo, so stow (bin/run-cmd-stow.sh) links dotfiles
# from here wherever the repo is cloned. A real directory already sitting there (the old
# dotfiles clone) is moved aside, not deleted.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$HOME/.omarchy-overrides"

# Cloned straight into ~/.omarchy-overrides: nothing to link. Without this the branch
# below moves the repo out from under itself -- which is how hpc001 ended up running
# everything from ~/.omarchy-overrides.bak.<stamp>.
if [ ! -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" = "$REPO_DIR" ]; then
  echo "Repo is already at $TARGET"
  exit 0
fi

if [ -L "$TARGET" ]; then
  if [ "$(readlink -f "$TARGET")" = "$REPO_DIR" ]; then
    echo "$TARGET already points to $REPO_DIR"
    exit 0
  fi
  rm "$TARGET"
elif [ -e "$TARGET" ]; then
  backup="$TARGET.bak.$(date +%Y%m%d%H%M%S)"
  mv "$TARGET" "$backup"
  echo "Moved existing $TARGET -> $backup"
fi

ln -s "$REPO_DIR" "$TARGET"
echo "Linked $TARGET -> $REPO_DIR"
