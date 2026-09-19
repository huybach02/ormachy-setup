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

-- Android Emulator: Float, center, and suppress rogue X11 reposition requests
o.window("^([eE]mulator|qemu-system-x86_64)$", {
  float = true,
  center = true,
  suppress_event = "x11configurerequest",
})

-- Android Emulator: Dock toolbar to right edge and loading state to center of phone (sync on drag/move)
local last_phone_x = nil
local last_phone_y = nil

local function sync_emulator_windows()
  local phone = nil
  local toolbar = nil
  local loading = nil

  for _, w in pairs(hl.get_windows()) do
    if w.class == "Emulator" or w.class == "qemu-system-x86_64" then
      if w.size and w.size.x < 100 then
        toolbar = w
      elseif w.size and w.size.x > 250 and w.size.y > 600 then
        phone = w
      elseif w.size and w.size.x > 100 and w.size.x <= 350 and w.size.y <= 350 then
        loading = w
      end
    end
  end

  if not phone or not phone.at or not phone.size then
    last_phone_x = nil
    last_phone_y = nil
    return
  end

  if phone.at.x ~= last_phone_x or phone.at.y ~= last_phone_y then
    last_phone_x = phone.at.x
    last_phone_y = phone.at.y

    -- Dock toolbar to right edge of phone, vertically centered
    if toolbar and toolbar.at and toolbar.size then
      local target_tb_x = phone.at.x + phone.size.x + 4
      local target_tb_y = math.floor(phone.at.y + (phone.size.y - toolbar.size.y) / 2)
      if toolbar.at.x ~= target_tb_x or toolbar.at.y ~= target_tb_y then
        hl.dispatch(hl.dsp.window.move({ window = toolbar, x = target_tb_x, y = target_tb_y }))
      end
    end

    -- Keep loading state centered directly over the phone screen
    if loading and loading.at and loading.size then
      local target_ld_x = math.floor(phone.at.x + (phone.size.x - loading.size.x) / 2)
      local target_ld_y = math.floor(phone.at.y + (phone.size.y - loading.size.y) / 2)
      if loading.at.x ~= target_ld_x or loading.at.y ~= target_ld_y then
        hl.dispatch(hl.dsp.window.move({ window = loading, x = target_ld_x, y = target_ld_y }))
      end
    end
  end
end

hl.on("window.open", sync_emulator_windows)
hl.on("window.title", sync_emulator_windows)
hl.timer(sync_emulator_windows, { timeout = 200, type = "repeat" })

