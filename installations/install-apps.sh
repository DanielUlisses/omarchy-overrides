#!/usr/bin/env bash

# Remmina (Pythian cloud PC), Solaar (Logitech devices) and Claude Desktop.

set -euo pipefail

# The -git builds match what bin/omarchy-context was tuned against. `pacman -Q` also
# matches providers, so a machine that already has the repo remmina/freerdp keeps them
# instead of hitting a package conflict under --noconfirm.
#
# freerdp-git builds clean again as of 2026-09-22 (verified at 3.31.1.r383.g1e8b630), so
# the old "fails to build" note is stale. It is kept enabled because it is the only
# variant that could ever drive the Lanvera/BSS AVD cloud PCs: the AUR PKGBUILD sets
# WITH_WEBVIEW_AAD_AUTH_HELPER=ON and ships /usr/bin/freerdp-webview-aad-helper, while
# the repo freerdp has WITH_WEBVIEW=OFF.
#
# Be aware this does NOT currently give a working AVD client. Attempted 2026-09-22 and it
# gets four steps in, then dies on an upstream bug:
#   1. gateway Entra ID login           -- works (webview helper)
#   2. per-host AVD access token        -- works, but only after adding
#                                          enablerdsaadauth:i:1 to the .rdp; without it
#                                          the host rejects the password prompt with 0x52E
#   3. POST /api/arm/v2/connections     -- response body arrives corrupted; jansson fails
#                                          at a FIXED offset (5831) with "'}' expected
#                                          near ':'", i.e. the body itself is mangled,
#                                          most likely chunked-encoding handling. Not a
#                                          timeout: /timeout:60000 and
#                                          /gateway:timeout:600000 change nothing.
#   4. once a response did parse, the gateway answered HTTP 403 FORBIDDEN, so there may
#      be a Conditional Access restriction waiting behind the parsing bug anyway.
# Lanvera/BSS therefore stay on the Chrome AVD web client (SUPER+SHIFT+L). Revisit if
# FreeRDP PR #13327 and the ARM response handling land upstream.
#
# Installing it replaces the repo freerdp, which pacman flags as a conflict. Answer yes:
# freerdp-git declares provides=(freerdp=...), so remmina-git stays satisfied -- the
# Pythian Remmina session was verified still working after the swap.
echo "Installing Remmina..."
pacman -Q freerdp >/dev/null 2>&1 || yay -S --noconfirm freerdp-git
pacman -Q remmina >/dev/null 2>&1 || yay -S --noconfirm remmina-git

echo "Installing Solaar..."
yay -S --noconfirm --needed solaar

echo "Installing Claude Desktop..."
yay -S --noconfirm --needed claude-desktop

if [ ! -f "$HOME/.local/share/remmina/group_rdp_pythian_172-16-0-16.remmina" ]; then
  echo "NOTE: the Pythian Remmina profile is missing; SUPER+SHIFT+R and context 1 expect" >&2
  echo "      ~/.local/share/remmina/group_rdp_pythian_172-16-0-16.remmina (recreate it in Remmina)." >&2
fi
