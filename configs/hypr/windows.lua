-- Application workspace assignment rules

-- Workspace 1: Edge -> Philip monitor
o.window("^[mM]icrosoft-edge.*$", { workspace = "1" })

-- Workspace 2: Helium -> AOC monitor
o.window("^helium.*$", { workspace = "2" })

-- Workspace 3: VSCode -> Philip monitor
o.window("^[cC]ode$", { workspace = "3" })

-- Workspace 4: Chromium -> AOC monitor
o.window("^[cC]hromium.*$", { workspace = "4" })

-- Omarchy Finder popup window rule
o.window("^omarchy-finder$", {
  float = true,
  center = true,
  size = { 1360, 820 },
})

-- Android Emulator: Float to keep phone aspect ratio and avoid empty side areas
o.window("^([eE]mulator|qemu-system-x86_64)$", {
  float = true,
})

