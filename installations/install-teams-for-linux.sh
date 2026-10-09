#!/bin/sh

echo "Installing Teams for Linux..."
sudo rm -rf "$HOME/.cache/yay/teams-for-linux" "$HOME/.cache/electron"
yay -S --noconfirm --needed teams-for-linux
