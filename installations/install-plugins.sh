#!/usr/bin/env bash

# Install the non-default Omarchy shell plugins and put them back where they sit in the
# bar. Built-in omarchy.* plugins ship with Omarchy and are not installed here.
#
# Needs a running Omarchy session: add/enable talk to omarchy-shell over IPC.
# Plugin settings (calendar ICS URLs, Jira/HASS tokens, ...) live in
# ~/.config/omarchy/shell.json and are NOT restored -- they hold secrets.

set -euo pipefail

PLUGINS_DIR="$HOME/.config/omarchy/plugins"

# id <TAB> git url <TAB> branch (- = default) <TAB> upstream url (- = none) <TAB> placement
# Placement is passed to `omarchy plugin enable`; - enables without placing (non-bar).
# Order matters: --after anchors must be enabled before the plugin that uses them.
plugins() {
  cat <<'EOF'
io.github.thetrueferret.decent-workspaces	https://github.com/TheTrueFerret/omarchy-decent-workspaces.git	-	-	--section left --after omarchy.menu
hass	https://github.com/konradk/hass.git	-	-	--section center --index 0
tmn73.jira	https://github.com/tmn73/omarchy-jira.git	-	-	--section center --after hass
omamail	https://github.com/huacnlee/omamail.git	-	-	--section center --after omarchy.clock
tobiasz-p.next-event	https://github.com/DanielUlisses/next-event.git	dev	https://github.com/tobiasz-p/next-event.git	--section center --after omamail
io.github.aryan-techie.todoist	https://github.com/DanielUlisses/omarchy-todoist.git	feat/tags	https://github.com/aryan-techie/omarchy-todoist.git	--section right --after omarchy.tray
claude-acc.usage	https://github.com/DanielUlisses/claude-acc-shell.git	-	-	--section right --after io.github.aryan-techie.todoist
crmne.hyprmoncfg	https://github.com/crmne/omarchy-hyprmoncfg.git	-	-	--section right --after omarchy.audio
shavanced.notification-center	https://github.com/Shavanced/omarchy-notification-center-plugin.git	-	-	--section right --after omarchy.power
io.github.sirjul1337.lock-explorer	https://github.com/SirJul1337/omarchy-lock-explorer.git	-	-	-
EOF
}

# Built-ins replaced by the plugins above.
DISABLE=(
  omarchy.lock       # -> io.github.sirjul1337.lock-explorer
  omarchy.workspaces # -> io.github.thetrueferret.decent-workspaces
  omarchy.agents     # -> claude-acc.usage
)

# Packages the plugins shell out to.
yay -S --noconfirm --needed hyprmoncfg-bin

if ! command -v claude-acc >/dev/null 2>&1 && [ ! -x "$HOME/.claude-switch/bin/claude-acc" ]; then
  echo "WARNING: claude-acc not found; claude-acc.usage will show no accounts." >&2
  echo "         Install it from https://github.com/Nemo-Illusionist/claude-code-account-switcher" >&2
fi

while IFS=$'\t' read -r id url branch upstream placement; do
  dir="$PLUGINS_DIR/$id"

  if [ -d "$dir" ]; then
    echo "Plugin $id already installed, skipping clone."
  else
    echo "Installing plugin $id from $url..."
    omarchy plugin add "$url" --yes

    # Forks: switch to the working branch on the fork, keep the original as `upstream`.
    [ "$upstream" = "-" ] || git -C "$dir" remote add upstream "$upstream"
    if [ "$branch" != "-" ]; then
      git -C "$dir" fetch origin "$branch"
      git -C "$dir" checkout -B "$branch" --track "origin/$branch"
      omarchy-shell shell rescanPlugins >/dev/null
    fi
  fi

  if [ "$placement" = "-" ]; then
    omarchy plugin enable "$id"
  else
    # shellcheck disable=SC2086 # placement is a list of flags
    omarchy plugin enable "$id" $placement ||
      omarchy plugin enable "$id" ${placement%% --*} # anchor missing: section only
  fi
done < <(plugins)

for id in "${DISABLE[@]}"; do
  omarchy plugin disable "$id"
done

echo "Omarchy plugins installed."
