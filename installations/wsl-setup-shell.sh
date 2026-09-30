#!/usr/bin/env bash

# User half of wsl-installation.sh: the Omarchy shell experience without Hyprland.
# The bash layer (aliases, fns, inputrc, starship/zoxide/mise init) comes from a git clone
# of basecamp/omarchy at ~/.local/share/omarchy, which bash/.bashrc picks up as
# OMARCHY_PATH when /usr/share/omarchy is absent. `git pull` there is the update path.

set -euo pipefail

OMARCHY_SRC="$HOME/.local/share/omarchy"
THEME_DIR="$HOME/.config/omarchy/themes/cyberpunk-reloaded"

if [ -d "$OMARCHY_SRC/.git" ]; then
  git -C "$OMARCHY_SRC" pull --ff-only --quiet
else
  git clone https://github.com/basecamp/omarchy.git "$OMARCHY_SRC"
fi

# Omarchy's terminal-app configs, copied only when absent so local edits survive reruns.
copy_config() {
  local src="$OMARCHY_SRC/config/$1" dest="$HOME/.config/$1"
  if [ -e "$dest" ]; then
    echo "Keeping existing $dest"
  else
    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
    echo "Installed $dest"
  fi
}
copy_config starship.toml
copy_config tmux
copy_config herdr
copy_config lazygit
copy_config btop
copy_config git/config

# Theme: only the terminal parts matter here (btop colors, nvim colorscheme).
[ -d "$THEME_DIR" ] || git clone https://github.com/DanielUlisses/omarchy-cyberpunk-reloaded-theme.git "$THEME_DIR"
mkdir -p "$HOME/.local/state/omarchy/current" "$HOME/.config/btop/themes"
ln -snf "$THEME_DIR" "$HOME/.local/state/omarchy/current/theme"
ln -snf "$HOME/.local/state/omarchy/current/theme/btop.theme" "$HOME/.config/btop/themes/current.theme"

# LazyVim as Omarchy ships it (omarchy-nvim stages it in /etc/skel).
if [ ! -e "$HOME/.config/nvim" ]; then
  cp -r /etc/skel/.config/nvim "$HOME/.config/nvim"
  [ -d /etc/skel/.local/share/nvim ] && mkdir -p "$HOME/.local/share" && cp -rn /etc/skel/.local/share/nvim "$HOME/.local/share/"
fi

# mise, as install/user/mise.sh does it, minus the AI CLIs.
mise settings set upgrade.auto_prune false
mise use -g node@latest gh@latest
mkdir -p "$HOME/Work/tries"

# claude-acc (Claude Code account switcher); bash/.bashrc already carries its init line.
if [ ! -x "$HOME/.claude-switch/bin/claude-acc" ]; then
  tmp=$(mktemp -d)
  url=$(curl -fsSL https://api.github.com/repos/Nemo-Illusionist/claude-code-account-switcher/releases/latest |
    jq -r '.assets[].browser_download_url | select(test("linux") and test("x86_64|amd64"))' | head -1)
  curl -fsSL "$url" -o "$tmp/asset"
  case "$url" in
  *.tar.gz | *.tgz) tar -xzf "$tmp/asset" -C "$tmp" ;;
  *.zip) unzip -q "$tmp/asset" -d "$tmp" ;;
  *) mv "$tmp/asset" "$tmp/claude-acc" ;;
  esac
  bin=$(find "$tmp" -type f -name 'claude-acc*' ! -name '*.sha256' | head -1)
  mkdir -p "$HOME/.claude-switch/bin"
  install -m 755 "$bin" "$HOME/.claude-switch/bin/claude-acc"
  rm -rf "$tmp"
  echo "Installed claude-acc (run 'claude-acc add <name>' to add accounts)"
fi

# Commit signing: 1Password for Windows ships a WSL-aware signer. Until it is there,
# signing stays off on this machine so commits keep working.
# The Store (MSIX) install only exposes it as an app alias on the Windows PATH; the
# classic installer puts it under AppData/Local/1Password/app/<n>.
signer=$(command -v op-ssh-sign-wsl.exe ||
  find "/mnt/c/Users/"*/AppData/Local/1Password/app/*/op-ssh-sign-wsl.exe 2>/dev/null | head -1 || true)
if [ -n "$signer" ]; then
  printf '[gpg "ssh"]\n\tprogram = %s\n' "$signer" >"$HOME/.gitconfig.local"
  echo "Commit signing via $signer"
else
  printf '# 1Password op-ssh-sign-wsl.exe not found; rerun installations/wsl-setup-shell.sh after installing it.\n[commit]\n\tgpgsign = false\n' >"$HOME/.gitconfig.local"
  echo "NOTE: 1Password WSL signer not found, commit signing disabled in ~/.gitconfig.local" >&2
fi


# Alacritty for Windows (it reads %APPDATA%\alacritty, not ~/.config) plus the Nerd Font
# Omarchy uses, installed per-user so no admin prompt is needed.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v cmd.exe >/dev/null && cmd.exe /c ver >/dev/null 2>&1; then
  appdata=$(wslpath "$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')")
  localappdata=$(wslpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")
  mkdir -p "$appdata/alacritty"
  cp "$REPO_DIR"/windows/alacritty/*.toml "$appdata/alacritty/"

  fonts="$localappdata/Microsoft/Windows/Fonts"
  if [ ! -f "$fonts/JetBrainsMonoNerdFont-Regular.ttf" ]; then
    tmp=$(mktemp -d)
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C "$tmp"
    mkdir -p "$fonts"
    for style in Regular Bold Italic BoldItalic; do cp "$tmp/JetBrainsMonoNerdFont-$style.ttf" "$fonts/"; done
    rm -rf "$tmp"
  fi
  for style in Regular Bold Italic BoldItalic; do
    reg.exe add 'HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts' /f /t REG_SZ \
      /v "JetBrainsMono Nerd Font $style (TrueType)" \
      /d "$(wslpath -w "$fonts/JetBrainsMonoNerdFont-$style.ttf")" >/dev/null
  done
  echo "Installed Alacritty config and JetBrainsMono Nerd Font on Windows"

  # Omarchy-style Win+1..9 / Win+Shift+1..9 desktops (windows/autohotkey), started at login.
  # The DLL is Windows-release specific: 2024-12-16 is the 24H2 build, verified on 26300.
  ahk_exe="$localappdata/Programs/AutoHotkey/v2/AutoHotkey64.exe"
  [ -f "$ahk_exe" ] ||
    (cd /mnt/c && cmd.exe /c "winget install --id AutoHotkey.AutoHotkey --scope user --silent --accept-package-agreements --accept-source-agreements" >/dev/null)
  mkdir -p "$appdata/autohotkey"
  cp "$REPO_DIR/windows/autohotkey/omarchy-desktops.ahk" "$appdata/autohotkey/"
  [ -f "$appdata/autohotkey/VirtualDesktopAccessor.dll" ] ||
    curl -fsSL https://github.com/Ciantic/VirtualDesktopAccessor/releases/download/2024-12-16-windows11/VirtualDesktopAccessor.dll \
      -o "$appdata/autohotkey/VirtualDesktopAccessor.dll"
  (cd /mnt/c && powershell.exe -NoProfile -Command '
    $exe = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    $ahk = "$env:APPDATA\autohotkey\omarchy-desktops.ahk"
    $lnk = Join-Path ([Environment]::GetFolderPath("Startup")) "omarchy-desktops.lnk"
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $s.TargetPath = $exe; $s.Arguments = "`"$ahk`""; $s.WorkingDirectory = Split-Path $ahk; $s.Save()
    Start-Process $exe -ArgumentList "`"$ahk`""' >/dev/null)
  echo "Installed AutoHotkey numbered desktops (Win+1..9, Win+Shift+1..9)"
else
  echo "NOTE: Windows interop unavailable, skipped Alacritty config + font" >&2
fi

echo "WSL shell setup completed."
