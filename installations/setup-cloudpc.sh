#!/usr/bin/env bash

# Recreate the non-secret half of ~/.local/share/avd/ for bin/omarchy-cloudpc, and say
# which .rdp files still have to be downloaded by hand. The .rdp files carry tenant ids
# and a Microsoft signature, so they never live in this repo: get each one from the
# Windows App web client (desktop tile -> "Download .rdp") as ~/.local/share/avd/<client>.rdp.

set -euo pipefail

AVD="$HOME/.local/share/avd"
mkdir -p "$AVD"
chmod 700 "$AVD"

# client <TAB> workspace (where its Entra login window gets parked) -- matches the
# cloudpc-<client> rules in overrides/omarchy-overrides.lua.
while IFS=$'\t' read -r client ws; do
  [ -f "$AVD/$client.ws" ] || echo "$ws" >"$AVD/$client.ws"
done <<'EOF'
f5	41
lanvera	42
bss	43
EOF

# Lanvera's host answers 0x52E unless the domain is empty -- see bin/omarchy-cloudpc.
# BSS and F5 must NOT get this.
[ -f "$AVD/lanvera.args" ] || echo "/d:" >"$AVD/lanvera.args"

missing=0
for client in f5 lanvera bss; do
  if [ ! -f "$AVD/$client.rdp" ]; then
    echo "NOTE: missing $AVD/$client.rdp -- download it from the Windows App web client." >&2
    missing=1
  fi
done
[ "$missing" = 0 ] && echo "Cloud PC files in place."
exit 0
