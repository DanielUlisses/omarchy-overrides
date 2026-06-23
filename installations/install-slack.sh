#!/bin/sh

echo "Installing Slack..."
sudo rm -rf "$HOME/.cache/yay/slack-desktop-wayland"
yay -S --noconfirm slack-desktop-wayland
