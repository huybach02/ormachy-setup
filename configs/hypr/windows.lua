-- Application workspace assignment rules

-- Workspace 1: Edge -> Philip monitor
o.window("^[mM]icrosoft-edge.*$", { workspace = "1" })

-- Workspace 2: Helium -> AOC monitor
o.window("^helium.*$", { workspace = "2" })

-- Workspace 3: VSCode -> Philip monitor
o.window("^[cC]ode$", { workspace = "3" })

-- Workspace 4: Chromium -> AOC monitor
o.window("^[cC]hromium.*$", { workspace = "4" })
