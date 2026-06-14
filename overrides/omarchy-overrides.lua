-- Monitor configuration
-- Chrome profiles: Default = personal, Profile 2 = pythian, Profile 3 = lanvera

hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1.25")

hl.monitor({ output = "DP-5", mode = "1920x1080@75", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-6", mode = "1920x1080@75", position = "1920x0", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "3840x0", scale = 1 })

-- hl.workspace_rule({ workspace = "1", monitor = "DP-5",  default = true })
-- hl.workspace_rule({ workspace = "2", monitor = "DP-6",  default = true })
-- hl.workspace_rule({ workspace = "3", monitor = "eDP-1", default = true })

-- This configuration uses the split-monitor-workspaces plugin to create workspaces that span multiple monitors. The plugin must be installed and configured separately.
-- mkdir -p ~/.config/hypr/plugins
-- cd ~/.config/hypr/plugins
-- git clone https://github.com/zjeffer/split-monitor-workspaces

package.path = package.path .. ";./?.lua;./?/init.lua"
local smw = require("plugins.split-monitor-workspaces")

smw.setup({
	workspace_count = 5, -- This will create 10 persistent workspaces on each monitor at startup
	monitor_priority = { "DP-5", "DP-6" }, -- This defines the order of monitors for workspace assignment
	keep_focused = true,
	enable_persistent_workspaces = true,
	-- link_monitors = true,
})

hl.unbind("SUPER + 1")
hl.unbind("SUPER + 2")
hl.unbind("SUPER + 3")
hl.unbind("SUPER + 4")
hl.unbind("SUPER + 5")
hl.unbind("SUPER + 6")
hl.unbind("SUPER + 7")
hl.unbind("SUPER + 8")
hl.unbind("SUPER + 9")
hl.unbind("SUPER + 0")

hl.unbind("SUPER + SHIFT + 1")
hl.unbind("SUPER + SHIFT + 2")
hl.unbind("SUPER + SHIFT + 3")
hl.unbind("SUPER + SHIFT + 4")
hl.unbind("SUPER + SHIFT + 5")
hl.unbind("SUPER + SHIFT + 6")
hl.unbind("SUPER + SHIFT + 7")
hl.unbind("SUPER + SHIFT + 8")
hl.unbind("SUPER + SHIFT + 9")
hl.unbind("SUPER + SHIFT + 0")

-- --- `get_amount_of_workspaces` is an easy helper function that simply returns the workspace_count you passed to the setup function.
local mainMod = "SUPER"
for i = 1, smw.get_amount_of_workspaces() do
	local n = tostring(i)
	local key = n == "10" and "0" or n -- SUPER+0 triggers workspace 10; pass "10" not "0" to avoid the wrap-around fallback hitting nonexistent workspace "0"
	hl.bind(mainMod .. " +" .. key, smw.workspace(n))
	hl.bind(mainMod .. " + SHIFT +" .. key, smw.move_to_workspace_silent(n))
end

--- Relative workspace switching using workspace().
--- "+N" / "-N" jump N workspaces forward/backward from the currently active one.
--- Wrapping behaviour follows the enable_wrapping config option.
hl.bind(mainMod .. " + PAGE_UP", smw.workspace("+1")) -- Next workspace (relative).
hl.bind(mainMod .. " + PAGE_DOWN", smw.workspace("-1")) -- Previous workspace (relative).

-- Prevent Ghostty windows from stealing focus on activate
hl.window_rule({
	match = { class = "com.mitchellh.ghostty" },
	suppress_event = "activatefocus activate",
	focus_on_activate = false,
})

-- Application keybindings (overrides omarchy defaults)
local desktop =
	'uwsm app -- remmina -c "/home/daniel/.local/share/remmina/pythian_rdp_pythian-notebook_172-16-0-16.remmina"'

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

o.bind("SUPER + SHIFT + B", "Browser", 'omarchy-launch-browser --profile-directory="Default"')
o.bind("SUPER + E", "Editor", { omarchy = "editor" })
o.bind("SUPER + SHIFT + E", "Email", "uwsm app -- thunderbird")
o.bind("SUPER + SHIFT + BACKSLASH", "Passwords", "uwsm app -- 1password --quick-access")
o.bind("SUPER + BACKSLASH", "1Password", "uwsm app -- 1password")
o.bind("SUPER + SHIFT + Y", "YouTube", 'omarchy-launch-webapp "https://youtube.com/" --profile-directory="Default"')
o.bind("SUPER + SHIFT + R", "Pythian Notebook", desktop)
o.bind("SUPER + SHIFT + M", "Meet", 'omarchy-launch-webapp "https://meet.google.com/" --profile-directory="Profile 2"')
o.bind("SUPER + SHIFT + T", "Teams", "uwsm app -- teams-for-linux")
o.bind(
	"SUPER + SHIFT + ALT + T",
	"Teams (personal)",
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
	'omarchy-launch-webapp "https://vertexaisearch.cloud.google.com/home/cid/a72e70f2-3125-4270-916e-2c345f90d694" --profile-directory="Profile 2"'
)
o.bind(
	"SUPER + SHIFT + L",
	"Lanvera Desktop",
	'omarchy-launch-webapp "https://windows.cloud.microsoft/webclient/avd/69350a1c-2543-4664-8ea9-d3850d5b2216/4b4019bc-77c4-408a-e788-08dbde32b101?endpointId=d136289c-954b-4134-92f0-ed117198fdbd#loginHint=TE.DU0816%40Lanvera.org" --profile-directory="Profile 3"'
)