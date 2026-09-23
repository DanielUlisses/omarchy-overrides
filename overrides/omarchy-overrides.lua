-- Monitor configuration
-- Per-client context workflow lives at the bottom of this file + bin/omarchy-context.

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
-- The layout the rest of this file assumes, kept in the "Home" profile:
--   DP-6 (Main, middle)  1..4   dev, one per context
--   eDP-1 (right)        10     Chromium / Pythian calendar+email, never context-switched
--   DP-5 (Third, left)   one app per workspace, in three rows, because DP-5 is portrait
--                        and two tiled windows on a 1080-wide panel are unusable:
--
--              ctx 1 Pythian   ctx 2 Lanvera   ctx 3 BSS        ctx 4 Personal
--   2n browser 21 chrome       22 chrome       23 chrome        24 chrome
--   3n chat    31 slack        32 teams        33 teams (BSS)   34 chrome (admin)
--   4n cloudpc 41 freerdp      42 freerdp      43 freerdp       44 remmina
--
-- The whole 4n row is native FreeRDP now, via bin/omarchy-cloudpc: 41 is the F5 Windows
-- 365 Cloud PC, 42 Lanvera, 43 BSS. Cloud PCs are named for the sub-client rather than
-- the context -- 41 sits in ctx 1 (Pythian) but is F5's, because Pythian will bring more.
-- 44 holds the 172.16.0.16 box on Remmina, moved off Pythian because it is becoming
-- personal. NOTE: hyprmoncfg has no rule for 44 yet (it generates 21-24, 31-34, 41-43),
-- so 44 opens on whichever monitor has focus until one is added to its profile.
--
-- Workspaces 5..9 are deliberately unruled and open on the focused monitor.
--
-- Fallback if hyprmoncfg is ever removed (`hyprmoncfg unmanage`): uncomment the block
-- below. Positions are the pre-hyprmoncfg ones and no longer match the current desk.
--
-- hl.monitor({ output = "DP-5", mode = "1920x1080@75", position = "0x0", scale = 1 })
-- hl.monitor({ output = "DP-6", mode = "1920x1080@75", position = "1920x0", scale = 1 })
-- hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "3840x0", scale = 1 })
--
-- for i = 1, 4 do
-- 	hl.workspace_rule({ workspace = tostring(i), monitor = "DP-6", default = i == 1 })
-- 	hl.workspace_rule({ workspace = tostring(20 + i), monitor = "DP-5", default = i == 1 })
-- end
-- for i = 1, 3 do
-- 	hl.workspace_rule({ workspace = tostring(30 + i), monitor = "DP-5" })
-- end
-- hl.workspace_rule({ workspace = "10", monitor = "eDP-1", default = true })

-- General hygiene against apps popping to front uninvited. Not what Focus mode
-- (SUPER+F9) is for -- that one is about silencing notifications.
hl.config({ misc = { focus_on_activate = false } })

-- Omarchy's default (looknfeel.lua) warps the cursor to the newly focused window on
-- every workspace change. That fights the SUPER+F<n> context switcher: repeated
-- presses walk DP-5 through its rows and hop DP-6, yanking the mouse off whatever
-- monitor it was actually sitting on each time. warp_on_change_workspace=0 only kills
-- the "move to last focused window" warp though -- Hyprland separately re-centers the
-- cursor onto a monitor whenever it becomes active (e.g. bin/omarchy-context's
-- `switch` ends every SUPER+F<n> press with `go(dev-workspace)` to land keyboard focus
-- on DP-6), and that one is gated by no_warps instead. Both have to be off.
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
-- the workspaces on whichever monitor the mouse is over. DP-5's row workspaces
-- (21..43) sit in that list right next to DP-6's (1..4) and eDP-1's (10), so scrolling
-- past DP-5's first/last open workspace (e.g. past Slack on 31) walks straight onto
-- DP-6 or eDP-1 instead of wrapping within DP-5. "m+1"/"m-1" is the monitor-scoped
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

-- Application keybindings (overrides omarchy defaults)
local cloudpc = "/home/daniel/repos/daniel/omarchy-overrides/bin/omarchy-cloudpc"
-- The 172.16.0.16 box is the only thing left on Remmina and is becoming personal.
local remmina_box = 'uwsm app -- remmina -c "/home/daniel/.local/share/remmina/group_rdp_pythian_172-16-0-16.remmina"'

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

o.bind("SUPER + SHIFT + B", "Browser", 'uwsm app -- google-chrome-stable --profile-directory="Default" --class=chrome-personal')
o.bind("SUPER + E", "Editor", { omarchy = "editor" })
o.bind("SUPER + SHIFT + E", "Email", "omarchy shell shell toggle omamail '{}'")
o.bind("SUPER + SHIFT + BACKSLASH", "Passwords", "uwsm app -- 1password --quick-access")
o.bind("SUPER + BACKSLASH", "1Password", "uwsm app -- 1password")
o.bind("SUPER + SHIFT + Y", "YouTube", 'omarchy-launch-webapp "https://youtube.com/" --profile-directory="Default"')
-- Cloud PCs, native FreeRDP via bin/omarchy-cloudpc. Each connect costs two browser
-- logins (gateway token, then per-host token); FreeRDP does not cache them.
o.bind("SUPER + SHIFT + R", "F5 Cloud PC", cloudpc .. " f5")
o.bind("SUPER + SHIFT + ALT + R", "BSS Cloud PC", cloudpc .. " bss")
o.bind("SUPER + SHIFT + CTRL + R", "Remote desktop 172.16.0.16", remmina_box)
o.bind("SUPER + SHIFT + M", "Meet", 'omarchy-launch-webapp "https://meet.google.com/" --profile-directory="Profile 1"')
o.bind("SUPER + SHIFT + T", "Teams", "uwsm app -- teams-for-linux")
o.bind(
	"SUPER + SHIFT + ALT + T",
	"Teams (BSS)",
	'uwsm app -- teams-for-linux --class=teams-personal --user-data-dir="/home/daniel/.config/teams-personal"'
)
o.bind("SUPER + SHIFT + S", "Slack", "uwsm app -- slack --enable-features=UseOzonePlatform --ozone-platform=wayland")
o.bind(
	"SUPER + SHIFT + W",
	"WhatsApp",
	'omarchy-launch-webapp "https://web.whatsapp.com/" --profile-directory="Default"'
)
o.bind(
	"SUPER + SHIFT + A",
	"Copilot",
	'omarchy-launch-webapp "https://copilot.microsoft.com" --profile-directory="Default"'
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
o.bind("SUPER + CTRL + M", "Next Event", "omarchy-shell shell toggle tobiasz-p.next-event")
o.bind("SUPER + SHIFT + L", "Lanvera Cloud PC", cloudpc .. " lanvera")

--------------------------------------------------------------------------------
-- Per-client contexts
--------------------------------------------------------------------------------
-- Chrome profiles as they actually exist in ~/.config/google-chrome/Local State:
--   Default = daniel (personal)   Profile 1 = pythian.com   Profile 2 = codingband.com (Lanvera)
--   Profile 3 = BSS               Profile 4 = ulissestech.com (admin / accounting)

local context = "/home/daniel/repos/daniel/omarchy-overrides/bin/omarchy-context"

-- Placement. `silent` so launching one context's stack never yanks focus out of another.
-- Match on class ONLY: adding a `title` to the match table stops the workspace
-- assignment firing at map time (verified on Hyprland 0.56.2).
local function place(class, workspace)
	o.window("^(" .. class .. ")$", { workspace = workspace .. " silent" })
end

-- Chat row (3n). Kept in sync by hand with the 3n entries in bin/omarchy-context.
place("slack", 31)
place("teams-for-linux", 32) -- default Teams instance == Lanvera (Pythian is on Slack)
place("teams-personal", 33) -- BSS Teams; class/data-dir keep the old "personal" name on purpose
place("chromium", 10)

-- NO rules for the client Chrome windows. Chrome runs one process for all profiles
-- sharing ~/.config/google-chrome, so every normal window reports the app_id of
-- whichever profile started the process -- a rule on chrome-pythian would swallow the
-- Lanvera and Personal windows too. bin/omarchy-context places them instead.

-- Cloud PC row (4n). Native FreeRDP sessions, launched by bin/omarchy-cloudpc, which
-- forces SDL_APP_ID=cloudpc-<client> so each one gets its own stable app_id. That is
-- what makes plain class rules work here -- unlike the chrome-* windows below, which
-- share a process and have to be placed by script.
place("cloudpc-f5", 41) -- named for the sub-client, not ctx 1's client (Pythian)
place("cloudpc-lanvera", 42)
place("cloudpc-bss", 43)

-- Every cloud PC's Entra login is the same class with the same title, and it maps
-- wherever the pointer is, so with two connects in flight you cannot tell which login
-- belongs to which host. bin/omarchy-cloudpc parks each one on its client's workspace by
-- matching the window's pid back to its own sdl-freerdp3. Float it so it stays a dialog
-- on top of that row instead of tiling into it and shrinking the session window.
o.window("^(freerdp-webview-aad-helper)$", {
	float = true,
	center = true,
	size = { 900, 760 },
})

-- Remmina now only holds the 172.16.0.16 box, which is moving to personal use, so it
-- sits on the Personal column rather than Pythian's. This catches the connection
-- manager as well as the session.
place("org.remmina.Remmina", 44)
-- Tiled, not floated -- it has the workspace to itself, so the old centred 1600x900
-- float just wasted a portrait panel.
o.window("^(org.remmina.Remmina)$", { float = false })

o.window("^(omawrite)$", {
	workspace = "special:notes silent",
	float = true,
	center = true,
	size = { 700, 550 },
})

for i = 1, 4 do
	o.bind("SUPER + F" .. i, "Context " .. i, context .. " switch " .. i)
	o.bind("SUPER + SHIFT + F" .. i, "Launch context " .. i, context .. " launch " .. i)
end
o.bind("SUPER + F5", "Comms <-> Cloud PC", context .. " toggle")
o.bind("SUPER + F9", "Focus mode", context .. " focus")
o.bind("SUPER + N", "Quick notes", context .. " notes")
o.bind("SUPER + SHIFT + Q", "Quit context apps", context .. " quit")

-- Known limitation: undocked (eDP-1 only) collapses 1..4/21..33 onto the laptop panel
-- and the F-key switching stops making sense. Use SUPER+1..9 directly there.
