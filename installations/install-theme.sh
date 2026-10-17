#!/usr/bin/env bash

# Tsukiyo (replaces cyberpunk-reloaded), plus the theme's own extras: GTK, Zen, Zed,
# starship, fastfetch, the bar/clock/lock-screen plugin clones, Hyprland motion
# (~/.config/hypr/tsukiyo.lua, required from hyprland.lua) and more -- see the theme's
# install-extras.sh. It backs up every file it replaces as *.pre-tsukiyo and undoes
# itself with `install-extras.sh --remove`.
#
# Runs after install-apps.sh: the extras only theme what already exists.

THEME_DIR="$HOME/.config/omarchy/themes/tsukiyo"

if [ -d "$THEME_DIR" ]; then
  echo "Theme tsukiyo already installed, skipping."
else
  echo "Installing tsukiyo theme..."
  omarchy theme install https://github.com/Arjun010011/omarchy-tsukiyo-theme.git
fi
omarchy theme set Tsukiyo

# Zed only gets its theme when ~/.config/zed exists, which Zed itself creates on first
# start -- create it so a fresh machine does not skip it.
command -v zeditor >/dev/null 2>&1 && mkdir -p "$HOME/.config/zed"

# Zen keeps its profile under ~/.config/zen only after the first start, so on a fresh
# machine the Zen part of the extras has nothing to theme yet.
[ -f "$HOME/.config/zen/profiles.ini" ] ||
  echo "NOTE: start Zen once, close it, then rerun $THEME_DIR/install-extras.sh to theme it." >&2

# Asks before adding the author's Dynamic Island plugin. Either answer is fine:
# install-plugins.sh installs it anyway, as the notification service.
"$THEME_DIR/install-extras.sh"
