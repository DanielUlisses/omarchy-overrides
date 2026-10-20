#!/usr/bin/env bash

# Install the non-default Omarchy shell plugins and put them back where they sit in the
# bar. Built-in omarchy.* plugins ship with Omarchy and are not installed here.
#
# Needs a running Omarchy session: add/enable talk to omarchy-shell over IPC.
# Plugin settings (calendar ICS URLs, HASS tokens, ...) live in
# ~/.config/omarchy/shell.json and are NOT restored -- they hold secrets.

set -euo pipefail

PLUGINS_DIR="$HOME/.config/omarchy/plugins"

# id <TAB> git url <TAB> branch (- = default) <TAB> upstream url (- = none) <TAB> placement
# Placement is passed to `omarchy plugin enable`; - enables without placing (non-bar);
# off installs it but leaves it disabled.
# Order matters: --after anchors must be enabled before the plugin that uses them.
#
# Forks (an upstream url is set) run from our own branch on the fork and are never sent
# upstream: `origin` is the fork, `upstream` the original, local `main` tracks
# upstream/main. To take upstream work: git fetch upstream, fast-forward main, review
# `git log main..upstream/main`, then merge (or cherry-pick) into the branch -- or drop it.
#
#   omarchy-dynamic-island  dev: the calendar rebuilt to replace NextEvent -- big feeds
#                           trimmed, real time zones, labelled/coloured feeds, declined
#                           invites hidden, keyword filter, a settings screen, and meetings
#                           opened in the Chrome profile picked per calendar. Calendars and
#                           those picks live in ~/.config/omarchy/dynamic-island/ (not in
#                           this repo: the .ics links are secret).
#   tobiasz-p.next-event    kept installed but off: the island's calendar replaces it.
plugins() {
  cat <<'EOF'
hass	https://github.com/konradk/hass.git	-	-	--section center --index 0
omarchy-dynamic-island	https://github.com/DanielUlisses/omarchy-dynamic-island.git	dev	https://github.com/Arjun010011/omarchy-dynamic-island.git	-
omamail	https://github.com/huacnlee/omamail.git	-	-	--section center --after omarchy.clock
tobiasz-p.next-event	https://github.com/DanielUlisses/next-event.git	dev	https://github.com/tobiasz-p/next-event.git	off
claude-acc.usage	https://github.com/DanielUlisses/claude-acc-shell.git	-	-	--section right --after omarchy.tray
jankeesvw.herdr	https://github.com/jankeesvw/omarchy-herdr.git	-	-	--section right --after omarchy.tray
crmne.hyprmoncfg	https://github.com/crmne/omarchy-hyprmoncfg.git	-	-	--section right --after omarchy.audio
io.github.sirjul1337.lock-explorer	https://github.com/SirJul1337/omarchy-lock-explorer.git	-	-	-
EOF
}

# Built-ins replaced by the plugins above.
DISABLE=(
  omarchy.lock       # -> io.github.sirjul1337.lock-explorer
  omarchy.agents     # -> claude-acc.usage

  # The island is a full replacement notification service (same IPC as the built-in, so
  # SUPER+comma and bin/omarchy-context meeting keep working): the built-in has to go or
  # both fight over the org.freedesktop.Notifications bus. Its settings are applied later,
  # by configure-dynamic-island.sh, once hyprmoncfg knows which monitor is the main one.
  omarchy.notifications # -> omarchy-dynamic-island
)

# Packages the plugins shell out to.
yay -S --noconfirm --needed hyprmoncfg-bin

if ! command -v claude-acc >/dev/null 2>&1 && [ ! -x "$HOME/.claude-switch/bin/claude-acc" ]; then
  echo "WARNING: claude-acc not found; claude-acc.usage will show no accounts." >&2
  echo "         Install it from https://github.com/Nemo-Illusionist/claude-code-account-switcher" >&2
fi

# Point a checkout at its fork: origin = the fork, upstream = the original, our branch
# checked out and local main tracking upstream/main. Also moves a checkout that was
# cloned from the original (the Tsukiyo theme adds the island that way) over to the fork.
# github.com/owner/repo, whether written https://…(.git) or git@github.com:…
repo_of() { sed -E 's#^(https?://|git@)##; s#:#/#; s#\.git$##; s#/$##' <<<"$1"; }

use_fork() {
  local dir=$1 url=$2 branch=$3 upstream=$4
  if [ "$(repo_of "$(git -C "$dir" remote get-url origin 2>/dev/null)")" != "$(repo_of "$url")" ]; then
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
      echo "WARNING: $dir has local changes; not switching it to $url." >&2
      return
    fi
    echo "Switching $(basename "$dir") to $url..."
    git -C "$dir" remote remove upstream 2>/dev/null || true
    git -C "$dir" remote rename origin upstream
    git -C "$dir" remote add origin "$url"
  fi
  if ! git -C "$dir" remote get-url upstream >/dev/null 2>&1; then
    git -C "$dir" remote add upstream "$upstream"
  elif [ "$(repo_of "$(git -C "$dir" remote get-url upstream)")" != "$(repo_of "$upstream")" ]; then
    git -C "$dir" remote set-url upstream "$upstream"
  fi
  git -C "$dir" fetch -q origin
  git -C "$dir" fetch -q upstream
  if [ "$branch" != "-" ] && [ "$(git -C "$dir" branch --show-current)" != "$branch" ]; then
    if git -C "$dir" show-ref -q --verify "refs/heads/$branch"; then
      git -C "$dir" checkout -q "$branch" # never reset a local branch: it may hold unpushed work
    else
      git -C "$dir" checkout -q -b "$branch" --track "origin/$branch"
    fi
  fi
  # main follows upstream; an existing one is only re-pointed, never moved.
  if git -C "$dir" show-ref -q --verify refs/remotes/upstream/main; then
    if git -C "$dir" show-ref -q --verify refs/heads/main; then
      git -C "$dir" branch -q --set-upstream-to=upstream/main main
    else
      git -C "$dir" branch -q --track main upstream/main
    fi
  fi
  omarchy-shell shell rescanPlugins >/dev/null
}

while IFS=$'\t' read -r id url branch upstream placement; do
  dir="$PLUGINS_DIR/$id"

  if [ -d "$dir" ]; then
    echo "Plugin $id already installed, skipping clone."
  else
    echo "Installing plugin $id from $url..."
    omarchy plugin add "$url" --yes
  fi
  [ "$upstream" = "-" ] || use_fork "$dir" "$url" "$branch" "$upstream"

  if [ "$placement" = "off" ]; then
    omarchy plugin disable "$id"
  elif [ "$placement" = "-" ]; then
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

# Built-in workspaces widget lives next to the menu, not in the center.
omarchy bar move omarchy.workspaces --section left --after omarchy.menu

echo "Omarchy plugins installed."
