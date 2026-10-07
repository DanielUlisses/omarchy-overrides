# omarchy-overrides

Dotfiles for Daniel's machines. `main` is the Omarchy (Arch + Hyprland) setup. The `wsl`
branch is this machine: Windows 11 with WSL Arch, keeping the Omarchy shell experience and
rebuilding the desktop side with Windows tools. Everything below is about `wsl`.

## Working rules

- Commit only on `wsl`, never `main`; add new commits, do not amend pushed ones.
- Deploy and let Daniel test before committing; commit and push when he says so.
- Commits are SSH-signed through 1Password, which must be unlocked ("failed to fill
  whole buffer" means it is locked).
- The repo is public. Never commit RDP files, calendar feed URLs, tokens, or personal
  email addresses; match on non-identifying text instead.
- Change files in `windows/`, then deploy with `bin/wsl-deploy` (below). Never edit the
  deployed copies directly: the next deploy overwrites them.

## Layout

| Path | What |
|---|---|
| `bash/.bashrc`, `git/`, `gh/` | stowed into `$HOME` (`bin/run-cmd-stow.sh`); the Omarchy bash layer is a git clone at `~/.local/share/omarchy` |
| `wsl-installation.sh` | entry point: packages (root), then `installations/wsl-setup-shell.sh`, then stow |
| `installations/wsl-setup-shell.sh` | user setup, Linux and Windows side (Alacritty, fonts, GlazeWM, Zebar, AutoHotkey, Chrome profile shortcuts, VS Code theme, win32yank, terraform via mise) |
| `windows/autohotkey/omarchy.ahk` | app keys, client contexts, cloud PCs, taskbar hiding, clipboard keys |
| `windows/glazewm/config.yaml` | tiling, workspaces, window rules, window keys |
| `windows/zebar/` | the top bar (pack `omarchy`: `main` on the primary monitor, `bar` on the others) |
| `windows/alacritty/` | terminal config (`alacritty.toml` + `theme.toml`) |
| `windows/wsl/.wslconfig` | WSL VM limits (8GB, 12 vCPUs), written only when absent |
| `bin/next-event-feeds` | calendar fetcher for the Zebar next-event widget |
| `bin/wsl-deploy` | deploy + reload the Windows-side configs |

## Deploying

`bin/wsl-deploy [ahk|glazewm|zebar|alacritty|all]` copies from `windows/` and reloads:

- `ahk` → `%APPDATA%\autohotkey\omarchy.ahk`, validated first (a script with errors is
  refused), then restarted detached.
- `glazewm` → `%USERPROFILE%\.glzr\glazewm\config.yaml`, then `wm-reload-config`.
- `zebar` → `%USERPROFILE%\.glzr\zebar\`, then Zebar restarts. `next-event-model.js` is
  fetched by setup from the DanielUlisses/next-event fork, not kept here.
- `alacritty` → `%APPDATA%\alacritty\`; Alacritty reloads by itself.

## The desktop

Monitors: left = portrait 1080x1920 (DISPLAY2, comms), centre = 1920x1080 primary
(DISPLAY3, dev), right = laptop (DISPLAY1).

Startup chain: the Startup-folder shortcut runs AutoHotkey (`omarchy.ahk`), which starts
GlazeWM, which starts Zebar. AutoHotkey reinstalls its keyboard hook whenever GlazeWM
(re)starts, so its keys win over GlazeWM's. GlazeWM's `shell-exec` cannot open `.ahk` or
`.lnk` files (it shows "Open with").

Workspaces (GlazeWM): 1-9 on the centre monitor, 10 on the laptop, and on the left monitor
one app per workspace in rows: 2n browser, 3n chat, 4n cloud PC, for clients n = 1 Pythian,
2 Lanvera, 3 BSS, 4 Personal. `S` is the scratchpad.

Client contexts (AutoHotkey `CONTEXTS`): Win+F<n> switches to client n (centre workspace n
plus its left-monitor browser row; again = next row), Win+Shift+F<n> launches its apps,
Win+Shift+Q quits them, Win+PgDn/PgUp step to the next/previous context.

Chrome profile directories here: Default = Pythian, Profile 3 = personal, Profile 7 =
Lanvera, Profile 8 = BSS. Setup puts a Start Menu shortcut per profile ("Chrome Pythian",
"Chrome Lanvera", ...) so Command Palette lists each.

Teams has one window per account and the title names it: Lanvera's (`Lanvera.org`) goes to
32, BSS's (`| Personal |`) to 33.

Cloud PCs: `.rdpw` files in `%APPDATA%\omarchy\rdp` (never in the repo). `OpenRdp` opens a
copy with only unsigned display/keyboard properties rewritten (windowed, one monitor,
`keyboardhook:i:0` so Win keys stay local); GlazeWM title rules put them on 41/42/43.
Win+Ctrl+Q kills the focused session. No keep-alive is possible against the idle lock:
posted input never reaches the session, and F5 signs `ClientRejectInjectedInput`.

The Windows taskbar is fully hidden (auto-hide + AutoHotkey hiding its windows, Win+Alt+B
toggles); Zebar's main bar carries the tray behind a chevron, weather, Claude usage
(`claude-acc usage` through WSL, rate-limited, polled every 10 minutes), the next calendar
event, and a Windows button that opens PowerToys Command Palette (`x-cmdpal:`, same as
Win+Space). Win+Esc is Omarchy's system menu (lock, sleep, restart, shut down, sign out).

Win+Alt+C is a quake-style drop-down running `claude --agent machine` in this repo:
an Alacritty window titled `machine-agent` (GlazeWM ignores it), always on top across the
top 60% of the primary monitor; the key hides it with the session kept, and brings it back.

Alacritty is launched from `%LOCALAPPDATA%\Programs\Alacritty`, a copy next to Microsoft's
current `conpty.dll` + `OpenConsole.exe`: the inbox ConPTY garbles herdr and Claude Code.
Alacritty swallows unclaimed Win combos, which herdr would otherwise print as `2;9u`.

Win+Ctrl+S is the same drop-down (title `secretary`) for the daily assistant: PowerShell
running `start.cmd` in the Windows-side `%USERPROFILE%\repos\secretary`.
## Pitfalls

- A Windows program started from WSL in the background (`&`) dies when the `wsl.exe` call
  exits. Start it in the foreground, or detached with PowerShell `Start-Process`.
- Run Windows CLIs through `powershell.exe -NoProfile -Command`; `cmd.exe /c` with quoted
  paths containing spaces breaks between WSL and cmd. Run them from `/mnt/c` (cd first) to
  avoid UNC working-directory warnings.
- Alacritty on Windows passes `-e` arguments to `wsl.exe` without re-quoting them; a
  multi-word command needs the escaped quotes `Terminal()` in omarchy.ahk adds, or only
  its first word runs.
- AutoHotkey v2 names are case-insensitive and built-in names cannot be variables: `log`,
  `file`, `local` all fail. `wsl-deploy ahk` validates before deploying.
- GlazeWM window rules run on `manage` only unless `on:` adds `title_change`; use that for
  windows whose title arrives late (Teams, cloud PCs, Chrome apps). Windows GlazeWM must
  not touch (overlays, popups) need an `ignore` rule: managing the Snipping Tool overlay
  closed it at once.
- A Zebar widget may only run programs allow-listed in `privileges.shellCommands` of
  `zpack.json`; the arguments are joined with spaces before matching `argsRegex`. Zebar
  pages cannot fetch most URLs themselves (CORS), hence the WSL helpers.
- The MX Keys screenshot key is mapped in Logi Options+ to send Print Screen, which
  AutoHotkey turns into Snipping Tool's region capture. Mouse buttons for Win+PgDn/PgUp are
  also set in Options+; neither is in this repo.
