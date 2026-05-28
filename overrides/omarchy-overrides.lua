-- Monitor configuration
-- Chrome profiles: Default = personal, Profile 2 = pythian, Profile 3 = lanvera

hl.env("GDK_SCALE", "1")
hl.env("GDK_DPI_SCALE", "1.25")

hl.monitor({ output = "DP-5",  mode = "1920x1080@75", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-6",  mode = "1920x1080@75", position = "1920x0", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "3840x0", scale = 1 })

hl.workspace_rule({ workspace = "1", monitor = "DP-5",  default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-5" })
hl.workspace_rule({ workspace = "3", monitor = "DP-5" })
hl.workspace_rule({ workspace = "4", monitor = "DP-6",  default = true })
hl.workspace_rule({ workspace = "9", monitor = "eDP-1", default = true })

-- Prevent Ghostty windows from stealing focus on activate
hl.window_rule({
  match = { class = "com.mitchellh.ghostty" },
  suppress_event = "activatefocus activate",
  focus_on_activate = false,
})

-- Application keybindings (overrides omarchy defaults)
local desktop = 'uwsm app -- remmina -c "/home/daniel/.local/share/remmina/pythian_rdp_pythian-notebook_172-16-0-16.remmina"'

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

o.bind("SUPER + SHIFT + B",       "Browser",          'omarchy-launch-browser --profile-directory="Default"')
o.bind("SUPER + E",               "Editor",           { omarchy = "editor" })
o.bind("SUPER + SHIFT + E",       "Email",            "uwsm app -- thunderbird")
o.bind("SUPER + SHIFT + BACKSLASH",   "Passwords",        "uwsm app -- 1password --quick-access")
o.bind("SUPER + BACKSLASH", "1Password",    "uwsm app -- 1password")
o.bind("SUPER + SHIFT + Y",       "YouTube",          'omarchy-launch-webapp "https://youtube.com/" --profile-directory="Default"')
o.bind("SUPER + SHIFT + R", "Pythian Notebook", desktop)
o.bind("SUPER + SHIFT + M",       "Meet",             'omarchy-launch-webapp "https://meet.google.com/" --profile-directory="Profile 2"')
o.bind("SUPER + SHIFT + T",       "Teams",            "uwsm app -- teams-for-linux")
o.bind("SUPER + SHIFT + ALT + T", "Teams (personal)", 'uwsm app -- teams-for-linux --class=teams-personal --user-data-dir="/home/daniel/.config/teams-personal"')
o.bind("SUPER + SHIFT + S",       "Slack",            "uwsm app -- slack --enable-features=UseOzonePlatform --ozone-platform=wayland")
o.bind("SUPER + SHIFT + W",       "WhatsApp",         'omarchy-launch-webapp "https://web.whatsapp.com/" --profile-directory="Default"')
o.bind("SUPER + SHIFT + A",       "Copilot",          'omarchy-launch-webapp "https://copilot.microsoft.com" --profile-directory="Default"')
o.bind("SUPER + SHIFT + ALT + A", "ChatGPT",          'omarchy-launch-webapp "https://chatgpt.com" --profile-directory="Default"')
o.bind("SUPER + SHIFT + G",       "Gemini Enterprise", 'omarchy-launch-webapp "https://vertexaisearch.cloud.google.com/home/cid/a72e70f2-3125-4270-916e-2c345f90d694" --profile-directory="Profile 2"')
