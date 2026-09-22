#!/usr/bin/env bash

# Point ~/.omarchy-overrides at this repo, so stow (bin/run-cmd-stow.sh) links dotfiles
# from here wherever the repo is cloned. A real directory already sitting there (the old
# dotfiles clone) is moved aside, not deleted.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$HOME/.omarchy-overrides"

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
