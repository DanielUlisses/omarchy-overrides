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
# cloudpc-<client> rules in overrides/omarchy-overrides.lua. Always rewritten: these are
# layout, not secrets, and a stale one parks the login on a workspace nobody looks at.
while IFS=$'\t' read -r client ws; do
  echo "$ws" >"$AVD/$client.ws"
done <<'EOF'
lanvera	6
bss	7
f5	8
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
