-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Philip (Primary - Left)
hl.monitor({ output = "HDMI-A-2", mode = "preferred", position = "0x0", scale = 1 })

-- AOC (Secondary - Right)
hl.monitor({ output = "DP-2", mode = "preferred", position = "1920x0", scale = 1 })

-- Fallback for any additional display
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Workspace bindings: Workspaces on Primary (Philip) and Secondary (AOC)
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-2", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-2", default = true })
