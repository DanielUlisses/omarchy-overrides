#!/usr/bin/env bash
# Mac side of the shared keyboard model (see macos/aerospace.toml). Run it on the Mac from a
# clone of this repo; it is safe to run again:
#   bash macos/setup.sh
# Not part of master-installation.sh, which is Omarchy-only.

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS. On Omarchy run master-installation.sh instead." >&2
  exit 1
fi

repo="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed. Install it from https://brew.sh, then run this again." >&2
  exit 1
fi

# 1. AeroSpace
if [[ -d /Applications/AeroSpace.app ]]; then
  echo "AeroSpace is already installed."
else
  brew install --cask nikitabobko/tap/aerospace
fi

# 2. Config: link the repo's file. AeroSpace reports an error when both ~/.aerospace.toml
# and ~/.config/aerospace/aerospace.toml exist, so an old ~/.aerospace.toml is moved aside.
target="${HOME}/.config/aerospace/aerospace.toml"
mkdir -p "$(dirname "${target}")"
for file in "${HOME}/.aerospace.toml" "${target}"; do
  if [[ -L "${file}" ]]; then
    rm -f "${file}"
  elif [[ -e "${file}" ]]; then
    backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    mv "${file}" "${backup}"
    echo "Backed up ${file} -> ${backup}"
  fi
done
ln -s "${repo}/macos/aerospace.toml" "${target}"
echo "Linked ${target} -> ${repo}/macos/aerospace.toml"

# 3. Give ctrl+left/right to AeroSpace: turn off Mission Control's "Move left a space" and
# "Move right a space" (symbolic hotkeys 79/80 and 81/82). AeroSpace replaces Spaces, so
# they have nothing left to do.
for id in 79 80 81 82; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "${id}" "<dict><key>enabled</key><false/></dict>"
done
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

# 4. AeroSpace's own recommendations: one Space across all displays ("Displays have
# separate Spaces" off, applies after logging out) and Mission Control grouped by app.
defaults write com.apple.spaces spans-displays -bool true
defaults write com.apple.dock expose-group-apps -bool true
killall Dock 2>/dev/null || true

# 5. Start it, or reload it if it is already running.
if pgrep -xq AeroSpace; then
  aerospace reload-config || true
else
  open -a AeroSpace
fi

cat <<'EOF'

Done. Still by hand, once:
  1. Allow AeroSpace under System Settings > Privacy & Security > Accessibility.
  2. Log out and back in, so "Displays have separate Spaces" turns off.
  3. Keyboard: input source U.S., and no modifier swap for the MX Keys
     (System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys at defaults).
     The key printed "cmd" must stay Command, "opt" Option.
  4. If ctrl+left/right still switch macOS Spaces, untick "Move left/right a space" under
     System Settings > Keyboard > Keyboard Shortcuts > Mission Control.
EOF
