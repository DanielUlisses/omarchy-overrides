#!/bin/sh

# Uninstall bundled apps only when they are installed.
uninstall_if_installed() {
  package="$1"

  if pacman -Q "$package" >/dev/null 2>&1; then
    yay -R --noconfirm "$package"
  else
    echo "Skipping uninstall for $package (not installed)."
  fi
}

uninstall_if_installed signal-desktop
uninstall_if_installed spotify
uninstall_if_installed code-insiders-bin
# The 172.16.10.156 box was the last Remmina session and is retired.
uninstall_if_installed remmina-git
uninstall_if_installed remmina
