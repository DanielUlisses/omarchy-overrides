-- Monitor configuration
-- Desk layout (fixed workspaces per monitor) lives at the bottom of this file + bin/omarchy-context.

hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1.25")

-- Hybrid GPU: every output (eDP-1, DP-5, DP-6) is wired to the Intel iGPU and Chrome
-- renders there (renderD129). Omarchy's nvidia.lua still points VA-API and GLX at the
-- GTX 1650, so video decoded on NVIDIA is handed to Intel as dmabufs, which shows up as
-- flickering pages with <video> and dropped inbound meeting video. Keep it all on Intel.
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")

-- Monitors and workspace-to-monitor rules are owned by hyprmoncfg, not this file.
-- Its generated ~/.config/hypr/hyprmoncfg-monitors.lua is dofile'd at the very end of
-- ~/.config/hypr/hyprland.lua, i.e. after this file, so anything declared here loses.
-- Edit the layout in the hyprmoncfg panel / TUI, or in ~/.config/hyprmoncfg/profiles/.
--
-- The layout the rest of this file assumes, kept in the "Home" and "Work" profiles.
-- Connector names swap between machines (and docks), so the profiles pin workspaces by
-- monitor *description*; the roles are what matter:
--   main (landscape, middle)  1 herdr   2 VS Code + Zed   3-4 free, for sharing in a call
--   left (portrait)           5 Zen     6 Lanvera VM      7 BSS VM      8 F5 (Pythian) VM
--   laptop (right)            9 meetings (Chrome, Meet, Zoom)   10 free
-- Chat apps (Slack, both Teams) own no workspace: each sits on its own special workspace
-- and is only toggled in to reply. See bin/omarchy-context.
--
-- Fallback if hyprmoncfg is ever removed (`hyprmoncfg unmanage`): uncomment the block
-- below and fix the connector names for that machine.
--
-- for i = 1, 4 do hl.workspace_rule({ workspace = tostring(i), monitor = "DP-5", default = i == 1 }) end
-- for i = 5, 8 do hl.workspace_rule({ workspace = tostring(i), monitor = "DP-6", default = i == 5 }) end
-- hl.workspace_rule({ workspace = "9", monitor = "eDP-1", default = true })
-- hl.workspace_rule({ workspace = "10", monitor = "eDP-1" })

-- General hygiene against apps popping to front uninvited. Not what Meeting mode
-- (SUPER+F9) is for -- that one is about silencing notifications.
hl.config({ misc = { focus_on_activate = false } })

-- Omarchy's default (looknfeel.lua) warps the cursor to the newly focused window on
-- every workspace change. That fights keyboard-driven jumps to another monitor (SUPER+F<n>
-- to a cloud PC on the left monitor, SUPER+<n> anywhere), yanking the mouse off whatever
-- monitor it was actually sitting on each time. warp_on_change_workspace=0 only kills
-- the "move to last focused window" warp though -- Hyprland separately re-centers the
-- cursor onto a monitor whenever it becomes active, and that one is gated by no_warps
-- instead. Both have to be off.
hl.config({ cursor = { warp_on_change_workspace = 0, no_warps = true } })

-- Drop shift:both_capslock_cancel from Omarchy's default kb_options
-- ("compose:caps,shift:both_capslock_cancel", default/hypr/input.lua). That option gives
-- both Shift keys a second-level Caps_Lock keysym so the pair toggles Caps Lock and a
-- single Shift cancels it. The AVD web client (Lanvera/BSS cloud PCs, SUPER+SHIFT+L)
-- mishandles the resulting Left Shift events: it forwards the press but never the release,
-- so Shift stays physically held on the remote Windows host -- visible on the remote's
-- on-screen keyboard -- until the local window loses focus and the client's blur handler
-- releases every key. Right Shift is unaffected, which is why this reads as a stuck
-- Left Shift rather than a dead keyboard.
--
-- Verified 2026-09-22 that nothing local is at fault before landing this: no Hyprland bind
-- is keyed on Shift_L (246 binds), the keymap compiles symmetrically for <LFSH>/<RTSH>,
-- it reproduces with omarchy-fcitx5.service stopped, a plain page in the same Chrome
-- profile logs matched keydown/keyup for both Shift keys, and it reproduces windowed and
-- in browser fullscreen alike. Keep Compose on Caps Lock; only the shift half goes.
-- Cost of dropping it: both-Shift no longer toggles Caps Lock.
hl.config({
	input = {
		kb_options = "compose:caps",
	},
})

-- Omarchy's default SUPER+scroll (mouse_down/mouse_up) binds use "e+1"/"e-1", which
-- cycles the single global, ID-sorted list of every currently open workspace -- not
-- the workspaces on whichever monitor the mouse is over. The left monitor's 5..8 sit in
-- that list right next to the main monitor's 1..4 and the laptop's 9..10, so scrolling
-- past the left monitor's last open workspace (e.g. past the F5 VM on 8) walks straight
-- onto the laptop instead of wrapping. "m+1"/"m-1" is the monitor-scoped
-- equivalent: it only cycles workspaces on the currently focused monitor, so with
-- follow_mouse (default) it stays on whichever monitor the cursor is actually over.
hl.unbind("SUPER + mouse_down")
hl.unbind("SUPER + mouse_up")
o.bind("SUPER + mouse_down", "Scroll active workspace forward", hl.dsp.focus({ workspace = "m+1" }))
o.bind("SUPER + mouse_up", "Scroll active workspace backward", hl.dsp.focus({ workspace = "m-1" }))

-- Prevent Ghostty windows from stealing focus on activate
hl.window_rule({
	match = { class = "com.mitchellh.ghostty" },
	suppress_event = "activatefocus activate",
	focus_on_activate = false,
})

-- oma-cast on SUPER+SPACE instead of Omarchy's app launcher (SUPER+ALT+SPACE still opens
-- Omarchy's apps menu). Only once installations/install-oma-cast.sh has linked the plugin,
-- which waits for Omarchy 4.5: binding a global shortcut nothing registered would leave
-- SUPER+SPACE dead. hl.dsp.global reaches the plugin directly, no process per keypress.
do
	local manifest = os.getenv("HOME") .. "/.config/omarchy/plugins/typecraft.oma-cast/manifest.json"
	local file = io.open(manifest, "r")
	if file then
		file:close()
		hl.unbind("SUPER + SPACE")
		o.bind("SUPER + SPACE", "oma-cast launcher", hl.dsp.global("oma-cast:toggle"))
	end
end

-- Application keybindings (overrides omarchy defaults)
local context = "/home/daniel/repos/daniel/omarchy-overrides/bin/omarchy-context"

hl.unbind("SUPER + SHIFT + SLASH")
hl.unbind("SUPER + SHIFT + A")
hl.unbind("SUPER + SHIFT + ALT + A")
hl.unbind("SUPER + SHIFT + B")
hl.unbind("SUPER + SHIFT + C")
hl.unbind("SUPER + SHIFT + E")
hl.unbind("SUPER + SHIFT + G")
hl.unbind("SUPER + SHIFT + M")
hl.unbind("SUPER + SHIFT + N")
hl.unbind("SUPER + SHIFT + S")
hl.unbind("SUPER + SHIFT + W")
hl.unbind("SUPER + SHIFT + Y")

-- Zen is the work browser (one space + container per client). Chrome stays the system
-- default: links from chat and calendar open there, on the laptop (see the rules below).
o.bind("SUPER + SHIFT + B", "Zen", context .. " zen")
o.bind("SUPER + E", "Editor", { omarchy = "editor" })
o.bind("SUPER + SHIFT + E", "Email", "omarchy shell shell toggle omamail '{}'")
o.bind("SUPER + BACKSLASH", "Passwords", "uwsm app -- 1password --quick-access")
o.bind("SUPER + SHIFT + BACKSLASH", "1Password", "uwsm app -- 1password")
o.bind("SUPER + SHIFT + Y", "YouTube", 'omarchy-launch-webapp "https://youtube.com/" --profile-directory="Default"')
o.bind("SUPER + SHIFT + M", "Meet", 'omarchy-launch-webapp "https://meet.google.com/" --profile-directory="Profile 1"')
o.bind(
	"SUPER + SHIFT + W",
	"WhatsApp",
	'omarchy-launch-webapp "https://web.whatsapp.com/" --profile-directory="Default"'
)
o.bind(
	"SUPER + SHIFT + ALT + A",
	"ChatGPT",
	'omarchy-launch-webapp "https://chatgpt.com" --profile-directory="Default"'
)
o.bind(
	"SUPER + SHIFT + G",
	"Gemini Enterprise",
	'omarchy-launch-webapp "https://vertexaisearch.cloud.google.com/home/cid/a72e70f2-3125-4270-916e-2c345f90d694" --profile-directory="Profile 1"'
)
o.bind(
	"SUPER + SHIFT + H",
	"Tempo",
	'omarchy-launch-webapp "https://pythian.atlassian.net/jira/apps/fa75e928-007a-4af4-9530-76503bcd4cba/ea7fda46-2015-4367-bd93-992fbf0c58ca/my-work/week?type=LIST" --profile-directory="Profile 1"'
)

-- Dynamic Island assistant (bin: the plugin's island-ctl). Bound here rather than with
-- `island-ctl keybinds --install`, which writes an untracked block into bindings.lua.
-- SUPER+SHIFT+A was Copilot; Omarchy's ChatGPT default stays unbound above.
local island = "/home/daniel/.local/bin/island-ctl"
o.bind("SUPER + A", "Island Chat", island .. " chat")
o.bind("SUPER + SHIFT + A", "Island agent home", island .. " home")
o.bind("SUPER + ALT + U", "Island usage", island .. " usage")
o.bind("SUPER + ALT + C", "Island calendar", island .. " calendar")
o.bind("SUPER + ALT + M", "Island meetings (transcripts)", island .. " meetings")
o.bind("SUPER + ALT + Y", "Allow the waiting agent request", island .. " approve")
o.bind("SUPER + ALT + N", "Deny the waiting agent request", island .. " deny")
o.bind("SUPER + ALT + J", "Jump to the agent that needs you", island .. " jump")
o.bind("SUPER + ALT + P", "Pin the island workspace", island .. " pin")

--------------------------------------------------------------------------------
-- Desk layout: fixed workspaces, one job each
--------------------------------------------------------------------------------
-- See the layout at the top of this file. Clients are split inside the apps (Zen spaces
-- + containers, herdr workspaces per devbox), not across workspaces.

-- Placement. `silent` so an app starting in the background never yanks focus.
-- Match on class ONLY: adding a `title` to the match table stops the workspace
-- assignment firing at map time (verified on Hyprland 0.56.2).
local function place(class, workspace)
	o.window("^(" .. class .. ")$", { workspace = workspace .. " silent" })
end

-- Main monitor
place("org.omarchy.herdr", 1) -- the herdr terminal started below
place("code|com\\.microsoft\\.VSCode", 2) -- VS Code sets com.microsoft.VSCode on Wayland; older builds "code"
place("dev.zed.Zed", 2)

-- Left monitor
place("zen", 5)
-- Cloud PCs: native FreeRDP via bin/omarchy-cloudpc, which forces SDL_APP_ID=cloudpc-<client>
-- so each one gets its own stable app_id. Named for the sub-client: F5 is Pythian's.
place("cloudpc-lanvera", 6)
place("cloudpc-bss", 7)
place("cloudpc-f5", 8)

-- Laptop: meetings. Chrome is the system default browser, so meeting links (Zoom, Meet)
-- from chat or calendar open here. Plain Chrome windows are all `google-chrome` now that
-- nothing passes --class any more. The Meet and Zoom web apps get their own
-- `chrome-<host>__...` app_id; the other web apps (WhatsApp, ChatGPT...) stay unruled.
place("google-chrome", 9)
place("chrome-meet\\.google\\.com__.*", 9)
place("chrome-.*zoom\\.us__.*", 9)
place("chromium", 10)

-- Chat apps: each on its own special workspace, shown only to reply (bin/omarchy-context
-- chat). A Teams call or Slack huddle runs where its app is; toggling it away keeps the
-- call going.
place("slack", "special:slack")
place("teams-for-linux", "special:teams") -- default Teams instance == Lanvera (Pythian is on Slack)
place("teams-personal", "special:teams-bss") -- BSS Teams; class/data-dir keep the old "personal" name on purpose

-- Every cloud PC's Entra login is the same class with the same title, and it maps
-- wherever the pointer is, so with two connects in flight you cannot tell which login
-- belongs to which host. bin/omarchy-cloudpc parks each one on its client's workspace by
-- matching the window's pid back to its own sdl-freerdp3. Float it so it stays a dialog
-- on top of that workspace instead of tiling into it and shrinking the session window.
o.window("^(freerdp-webview-aad-helper)$", {
	float = true,
	center = true,
	size = { 900, 760 },
})

o.window("^(omawrite)$", {
	workspace = "special:notes silent",
	float = true,
	center = true,
	size = { 700, 550 },
})

-- Secretary drop-down (bin/omarchy-secretary): the daily assistant on its own special
-- workspace, floating across the top like the Windows Win+Ctrl+S one. SUPER+SHIFT+S was
-- Omarchy's Google Maps (unbound above).
o.window("^(secretary)$", {
	workspace = "special:secretary silent",
	float = true,
	size = { "(monitor_w*0.9)", "(monitor_h*0.6)" },
	move = { "(monitor_w*0.05)", "(monitor_h*0.03)" },
})
o.bind("SUPER + SHIFT + S", "Secretary", "/home/daniel/repos/daniel/omarchy-overrides/bin/omarchy-secretary")

-- Music drop-down (bin/omarchy-music): cliamp on its own special workspace, floating and
-- centered, so it plays hidden and comes back on the same key. Replaces Omarchy's
-- SUPER+SHIFT+ALT+M "Music TUI", which launched or focused cliamp on a normal workspace;
-- that key stays unbound and the drop-down lives on SUPER+CTRL+M (was NextEvent).
o.window("^(cliamp)$", {
	workspace = "special:music silent",
	float = true,
	center = true,
	size = { "(monitor_w*0.6)", "(monitor_h*0.6)" },
})
hl.unbind("SUPER + SHIFT + ALT + M")
o.bind("SUPER + CTRL + M", "Music", "/home/daniel/repos/daniel/omarchy-overrides/bin/omarchy-music")

-- Always running: chat lands hidden on its special workspace, herdr on 1.
o.launch_on_start("slack --enable-features=UseOzonePlatform --ozone-platform=wayland")
o.launch_on_start("teams-for-linux")
o.launch_on_start("teams-for-linux --class=teams-personal --user-data-dir=/home/daniel/.config/teams-personal")
o.exec_on_start("omarchy-launch-tui herdr")

-- A focused cloud PC asks for keyboard-shortcut inhibition, so without dont_inhibit these
-- keys go to Windows instead (SUPER+F1 opened the remote browser's help). Only these
-- binds escape; every other SUPER chord still reaches the VM.
local escape = { dont_inhibit = true }
o.bind("SUPER + F1", "Lanvera Cloud PC", context .. " vm lanvera", escape)
o.bind("SUPER + F2", "BSS Cloud PC", context .. " vm bss", escape)
o.bind("SUPER + F3", "F5 (Pythian) Cloud PC", context .. " vm f5", escape)
o.bind("SUPER + SHIFT + F1", "Cycle left monitor", context .. " cycle", escape)
-- Chat on SUPER+ALT + the home row: S Slack (Pythian), A Lanvera Teams, D BSS Teams.
-- SUPER+ALT+S was Omarchy's "Move window to scratchpad"; SUPER+S (toggle scratchpad) stays.
hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Slack", context .. " chat slack", escape)
o.bind("SUPER + ALT + A", "Teams (Lanvera)", context .. " chat teams", escape)
o.bind("SUPER + ALT + D", "Teams (BSS)", context .. " chat teams-bss", escape)
o.bind("SUPER + F9", "Meeting mode", context .. " meeting", escape)
o.bind("SUPER + N", "Quick notes", context .. " notes")

-- Mouse side buttons: in Zen they cycle spaces (Zen's own CTRL+ALT+Left/Right). A bound
-- button is swallowed for every app, so elsewhere they are re-sent as ALT+Left/Right,
-- which is back/forward in Chrome, VS Code and Zed. Terminals get nothing: ALT+arrows
-- there are word motions or herdr keys, not navigation.
-- Down/up split as in Omarchy's bindings/clipboard.lua (send_shortcut can leave keys stuck).
local function send_once(mods, key)
	hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
	hl.timer(function()
		hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
	end, { timeout = 50, type = "oneshot" })
end

local function is_terminal(window)
	for _, tag in ipairs(window.tags or {}) do
		if tag:gsub("%*$", "") == "terminal" then
			return true
		end
	end
	return false
end

local function side_button(key)
	return function()
		local window = hl.get_active_window()
		if not window then
			return
		elseif window.class == "zen" then
			send_once("CTRL ALT", key)
		elseif not is_terminal(window) then
			send_once("ALT", key)
		end
	end
end

o.bind("mouse:275", "Back / previous Zen space", side_button("Left"))
o.bind("mouse:276", "Forward / next Zen space", side_button("Right"))

-- Undocked (laptop only) every workspace collapses onto the laptop panel; SUPER+1..0
-- and the F-keys still work, there is just one screen to show them on.
