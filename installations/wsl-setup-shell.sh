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
mise use -g node@latest gh@latest terraform@latest
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
  # WSL VM limits (8GB instead of half the host RAM); only written when absent.
  userprofile=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
  [ -f "$userprofile/.wslconfig" ] || sed 's/$/\r/' "$REPO_DIR/windows/wsl/.wslconfig" >"$userprofile/.wslconfig"

  # Neovim's clipboard provider on WSL (LazyVim yanks/pastes through "+). It is a Windows
  # binary, kept on the Windows side and linked onto the Linux PATH.
  if [ ! -x "$localappdata/Programs/win32yank/win32yank.exe" ]; then
    tmp=$(mktemp -d)
    curl -fsSL https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip -o "$tmp/w.zip"
    mkdir -p "$localappdata/Programs/win32yank"
    unzip -o -q "$tmp/w.zip" win32yank.exe -d "$localappdata/Programs/win32yank"
    rm -rf "$tmp"
  fi
  mkdir -p "$HOME/.local/bin"
  ln -sf "$localappdata/Programs/win32yank/win32yank.exe" "$HOME/.local/bin/win32yank.exe"

  # Alacritty with a current ConPTY: Windows' inbox one re-renders full-screen programs
  # (herdr, Claude Code) and leaves stray characters behind. Alacritty loads conpty.dll
  # (and its OpenConsole.exe) from its own directory, so a user-local copy carries them
  # without touching Program Files; omarchy.ahk launches this copy when it exists.
  alacritty_dir="$localappdata/Programs/Alacritty"
  if [ -f "/mnt/c/Program Files/Alacritty/alacritty.exe" ]; then
    mkdir -p "$alacritty_dir"
    rm -f "$alacritty_dir/alacritty.exe" # the copy keeps Program Files' read-only bit
    cp "/mnt/c/Program Files/Alacritty/alacritty.exe" "$alacritty_dir/"
    tmp=$(mktemp -d)
    v=$(curl -fsSL https://api.nuget.org/v3-flatcontainer/microsoft.windows.console.conpty/index.json |
      jq -r '.versions | map(select(test("-") | not)) | last')
    curl -fsSL "https://api.nuget.org/v3-flatcontainer/microsoft.windows.console.conpty/$v/microsoft.windows.console.conpty.$v.nupkg" -o "$tmp/conpty.zip"
    unzip -o -q -j "$tmp/conpty.zip" runtimes/win-x64/native/conpty.dll build/native/runtimes/x64/OpenConsole.exe -d "$alacritty_dir"
    rm -rf "$tmp"
    echo "Alacritty uses ConPTY $v"
  fi

  # VS Code: the Omarchy theme's own extension. Themes load in the Windows client, not the
  # WSL server, so it goes into Windows VS Code; only the colorTheme line of the user's
  # settings is touched (the file has comments, so no JSON rewrite).
  vsix=$(ls "$THEME_DIR"/vscode-extension/*.vsix 2>/dev/null | head -1)
  vscode_settings="$appdata/Code/User/settings.json"
  if [ -n "$vsix" ] && [ -f "$localappdata/Programs/Microsoft VS Code/bin/code.cmd" ]; then
    cp "$vsix" "$localappdata/Temp/omarchy-theme.vsix"
    (cd /mnt/c && powershell.exe -NoProfile -Command '& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension "$env:TEMP\omarchy-theme.vsix" --force' >/dev/null 2>&1)
    rm -f "$localappdata/Temp/omarchy-theme.vsix"
    theme=$(jq -r .name "$THEME_DIR/vscode.json")
    if [ -f "$vscode_settings" ] && grep -q '"workbench.colorTheme"' "$vscode_settings"; then
      sed -i "s/^\(\s*\"workbench.colorTheme\": \)\"[^\"]*\"/\1\"$theme\"/" "$vscode_settings"
    elif [ ! -f "$vscode_settings" ]; then
      mkdir -p "$(dirname "$vscode_settings")"
      printf '{\n  "workbench.colorTheme": "%s"\n}\n' "$theme" >"$vscode_settings"
    fi
    echo "VS Code theme: $theme"
  fi

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

  # GlazeWM (Hyprland's role) and Zebar (the bar, with Claude usage) from windows/glazewm
  # and windows/zebar, into %USERPROFILE%\.glzr. GlazeWM starts Zebar itself.
  (cd /mnt/c && for id in glzr-io.glazewm glzr-io.zebar; do
    cmd.exe /c "winget install --id $id --silent --accept-package-agreements --accept-source-agreements" >/dev/null
  done)
  mkdir -p "$userprofile/.glzr/glazewm" "$userprofile/.glzr/zebar/omarchy"
  cp "$REPO_DIR/windows/glazewm/config.yaml" "$userprofile/.glzr/glazewm/"
  cp "$REPO_DIR/windows/zebar/settings.json" "$userprofile/.glzr/zebar/"
  cp "$REPO_DIR"/windows/zebar/omarchy/* "$userprofile/.glzr/zebar/omarchy/"
  # The next-event widget reuses the Omarchy plugin's model (fork with our fixes).
  curl -fsSL https://raw.githubusercontent.com/DanielUlisses/next-event/dev/Model.js \
    -o "$userprofile/.glzr/zebar/omarchy/next-event-model.js"
  mkdir -p "$HOME/.config/next-event"
  [ -f "$HOME/.config/next-event/feeds" ] ||
    printf '# label|chrome profile|private .ics url, one calendar per line (see bin/next-event-feeds)\n' >"$HOME/.config/next-event/feeds"
  echo "Installed GlazeWM and Zebar"

  # Omarchy app launchers and client-context keys (Win as Super) from windows/autohotkey.
  # The script is what starts at login, and it starts GlazeWM, so its keyboard hook can
  # stay on top of GlazeWM's (see the top of omarchy.ahk).
  ahk_exe="$localappdata/Programs/AutoHotkey/v2/AutoHotkey64.exe"
  [ -f "$ahk_exe" ] ||
    (cd /mnt/c && cmd.exe /c "winget install --id AutoHotkey.AutoHotkey --scope user --silent --accept-package-agreements --accept-source-agreements" >/dev/null)
  mkdir -p "$appdata/autohotkey"
  cp "$REPO_DIR/windows/autohotkey/omarchy.ahk" "$appdata/autohotkey/"
  (cd /mnt/c && powershell.exe -NoProfile -Command '
    $exe = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
    $ahk = "$env:APPDATA\autohotkey\omarchy.ahk"
    $startup = [Environment]::GetFolderPath("Startup")
    Remove-Item (Join-Path $startup "glazewm.lnk") -ErrorAction SilentlyContinue
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startup "omarchy.lnk"))
    $s.TargetPath = $exe; $s.Arguments = "`"$ahk`""; $s.WorkingDirectory = Split-Path $ahk; $s.Save()
    Start-Process $exe -ArgumentList "`"$ahk`""
    if (Get-Process glazewm -ErrorAction SilentlyContinue) {
      & "$env:ProgramFiles\glzr.io\GlazeWM\cli\glazewm.exe" command wm-reload-config
    }' >/dev/null)
  echo "Installed AutoHotkey Omarchy keybindings"
else
  echo "NOTE: Windows interop unavailable, skipped Alacritty config + font" >&2
fi

echo "WSL shell setup completed."
