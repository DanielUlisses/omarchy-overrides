#!/usr/bin/env bash

# Remmina (the 172.16.0.16 box), Solaar (Logitech devices) and Claude Desktop.

set -euo pipefail

# The -git builds match what bin/omarchy-context was tuned against. `pacman -Q` also
# matches providers, so a machine that already has the repo remmina/freerdp keeps them
# instead of hitting a package conflict under --noconfirm.
#
# freerdp-git builds clean again as of 2026-09-22 (verified at 3.31.1.r383.g1e8b630), so
# the old "fails to build" note is stale. It is kept enabled because it is the only
# variant that can drive the AVD/Windows 365 cloud PCs: the AUR PKGBUILD sets
# WITH_WEBVIEW_AAD_AUTH_HELPER=ON and ships /usr/bin/freerdp-webview-aad-helper, while
# the repo freerdp has WITH_WEBVIEW=OFF.
#
# All three cloud PCs (F5, Lanvera, BSS) run on this via bin/omarchy-cloudpc.
# Getting there needed four things, recorded so they are not rediscovered the hard way:
#   1. the webview helper, for the Entra ID logins (gateway token, then per-host token)
#   2. per-host auth differs per host pool, and the .rdp says which:
#        BSS      enablerdsaadauth:i:1                     -> token auth, no prompt
#        F5       targetisaadjoined:i:1 + enablerdsaadauth:i:0 -> works as shipped
#        Lanvera  neither property                         -> credential prompt
#      Do NOT add enablerdsaadauth to a pool that omits it: forcing it on Lanvera made
#      the ARM connections response come back unparseable, which looked like a FreeRDP
#      bug but was self-inflicted.
#   3. Lanvera needs an EMPTY domain. FreeRDP defaults to "AzureAD" (PR #11892) and the
#      host answers 0x52E. "/d:" lives in ~/.local/share/avd/lanvera.args.
#   4. /timeout:60000, because the gateway holds POST /api/arm/v2/connections open while
#      it orchestrates a session host.
# The .rdp files stay in ~/.local/share/avd/ -- they carry tenant ids and a signature.
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
  echo "NOTE: the Remmina profile is missing; SUPER+SHIFT+CTRL+R and context 4 expect" >&2
  echo "      ~/.local/share/remmina/group_rdp_pythian_172-16-0-16.remmina (recreate it in Remmina)." >&2
fi
