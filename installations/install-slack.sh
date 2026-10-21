#!/bin/sh

# slack-desktop-wayland is gone from the AUR. The -jetm build is the maintained Wayland
# variant: it provides slack-desktop, runs on electron44-bin and keeps the `slack`
# binary and window class, so the keybind and the workspace 31 rule work unchanged.
echo "Installing Slack..."
# The old slack-desktop-wayland conflicts with the -jetm build, and under --noconfirm
# pacman answers "no" to removing it, so the install aborts. Take it out first.
if pacman -Q slack-desktop-wayland >/dev/null 2>&1; then
  yay -R --noconfirm slack-desktop-wayland
fi
sudo rm -rf "$HOME/.cache/yay/slack-desktop-wayland-jetm"
yay -S --noconfirm --needed slack-desktop-wayland-jetm
