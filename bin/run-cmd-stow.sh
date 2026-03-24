#!/usr/bin/env bash

set -euo pipefail

DOTFILES_REPO="${HOME}/.omarchy-overrides"

if ! command -v stow >/dev/null 2>&1; then
  echo "Stow is not installed. Install it first."
  exit 1
fi

if [[ ! -d "${DOTFILES_REPO}" ]]; then
  echo "Dotfiles repo not found: ${DOTFILES_REPO}" >&2
  exit 1
fi

backup_if_needed() {
  local target="$1"
  if [[ -L "${target}" ]]; then
    rm -f "${target}"
    echo "Removed pre-existing symlink ${target}"
    return
  fi

  if [[ -e "${target}" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "${target}" "${backup}"
    echo "Backed up ${target} -> ${backup}"
  fi
}

backup_if_needed "${HOME}/.config/gh/config.yml"
backup_if_needed "${HOME}/.config/git/ignore"
backup_if_needed "${HOME}/.gitconfig"

cd "${DOTFILES_REPO}"

echo "Applying stow overrides from ${DOTFILES_REPO}..."
stow bash
stow gh
stow git
