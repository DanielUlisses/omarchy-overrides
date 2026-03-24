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
