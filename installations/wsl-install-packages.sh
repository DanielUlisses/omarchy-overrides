#!/usr/bin/env bash
# Root half of wsl-installation.sh: Omarchy repo + the shell/dev packages Omarchy ships.
# Run with: sudo bash installations/wsl-install-packages.sh
set -euo pipefail

TARGET_USER="${SUDO_USER:-daniel}"
OMARCHY_KEY=40DFB630FF42BCFFB047046CF0134EE680CAC571

echo "==> Windows interop (.exe) under systemd"
# With systemd=true, systemd-binfmt resets binfmt_misc and WSL's own handler is lost,
# so explorer.exe, npiperelay.exe, code, etc. fail with "Exec format error".
if [ ! -f /etc/binfmt.d/WSLInterop.conf ]; then
  echo ':WSLInterop:M::MZ::/init:PF' >/etc/binfmt.d/WSLInterop.conf
  systemctl restart systemd-binfmt
fi

echo "==> Locale"
# The image sets LANG=en_US.UTF-8 without generating it: perl (stow) warns on every run
# and printf falls back to C, which breaks the Nerd Font glyphs Omarchy's aliases print.
if ! locale -a 2>/dev/null | grep -qi '^en_US.utf8$'; then
  sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  locale-gen
fi

echo "==> Arch keyring"
# The WSL Arch image ships a stale, never-populated keyring: every current packager's
# signature then fails as "unknown trust" and pacman calls the packages corrupted.
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --needed --noconfirm archlinux-keyring

echo "==> Trusting the Omarchy repo key"
pacman-key --list-keys "$OMARCHY_KEY" &>/dev/null || {
  pacman-key --recv-keys "$OMARCHY_KEY" --keyserver keys.openpgp.org
  pacman-key --lsign-key "$OMARCHY_KEY"
}

echo "==> Adding [omarchy] repo to /etc/pacman.conf"
if ! grep -q '^\[omarchy\]' /etc/pacman.conf; then
  cp /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%Y%m%d%H%M%S)"
  printf '\n[omarchy]\nServer = https://pkgs.omarchy.org/stable/$arch\n' >>/etc/pacman.conf
fi
# Same nicer pacman output Omarchy ships with
sed -i 's/^#Color$/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

PKGS=(
  omarchy-keyring yay stow
  # Nav & search
  eza fzf zoxide fd ripgrep bat
  # Prompt & docs
  starship bash-completion tldr man-db less plocate
  # System info
  btop fastfetch dua-cli inxi
  # Utilities
  jq gum unzip whois inetutils inotify-tools rsync socat yt-dlp imagemagick openssh
  # Editor & multiplexers
  neovim omarchy-nvim tmux herdr
  # Git/Docker TUIs + Docker
  lazygit lazydocker docker docker-buildx docker-compose
  # mise + try
  mise-bin tobi-try
  # Build/lang deps
  clang llvm ruby lua51 luarocks tree-sitter-cli libyaml mariadb-libs postgresql-libs python-poetry-core
  # Cloud
  azure-cli kubectl
)

echo "==> Installing packages"
pacman -Syu --needed --noconfirm "${PKGS[@]}"

echo "==> Docker service + group"
systemctl enable --now docker.service
usermod -aG docker "$TARGET_USER"

echo "==> plocate index"
systemctl enable --now plocate-updatedb.timer || true

echo "Root setup done. Open a NEW WSL shell afterwards so the docker group applies."
