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
--   4n cloudpc 41 remmina      42 avd          43 avd           --
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

-- Prevent Ghostty windows from stealing focus on activate
hl.window_rule({
	match = { class = "com.mitchellh.ghostty" },
	suppress_event = "activatefocus activate",
	focus_on_activate = false,
})

-- Application keybindings (overrides omarchy defaults)
local desktop = 'uwsm app -- remmina -c "/home/daniel/.local/share/remmina/group_rdp_pythian_172-16-0-16.remmina"'

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
o.bind("SUPER + SHIFT + R", "Pythian Notebook", desktop)
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
o.bind("SUPER + CTRL + M", "Next Event", "omarchy-shell shell toggle tobiasz-p.next-event")
o.bind(
	"SUPER + SHIFT + L",
	"Lanvera Desktop",
	'omarchy-launch-webapp "https://windows.cloud.microsoft/webclient/avd/69350a1c-2543-4664-8ea9-d3850d5b2216/4b4019bc-77c4-408a-e788-08dbde32b101?endpointId=d136289c-954b-4134-92f0-ed117198fdbd#loginHint=TE.DU0816%40Lanvera.org" --profile-directory="Profile 2"'
)

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

-- Cloud PCs run windowed, so SUPER combos keep reaching Hyprland. Remmina holds the
-- Pythian RDP credentials and there is only one session, so its class is already
-- unique per client -- no xfreerdp/wm-class juggling needed. This catches Remmina's
-- connection manager as well as the session; both belong on the Pythian cloud layer.
place("org.remmina.Remmina", 41)
-- Tiled, not floated. Remmina has workspace 41 to itself now, so the old centred
-- 1600x900 float just wasted a portrait panel.
o.window("^(org.remmina.Remmina)$", { float = false })
-- Lanvera and BSS cloud PCs are AVD web clients in Chrome app mode, so they are
-- placed by the script for the same reason the client browsers are.

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
