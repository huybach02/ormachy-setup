-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Screenshot shortcut (Windows-like Super+Shift+S)
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")

-- Clipboard history (Windows-like Super+V)
hl.unbind("SUPER + V")
o.bind("SUPER + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")

-- Toggle Vietnamese input method (Alt + Left Shift)
o.bind("ALT + Shift_L", "Toggle Vietnamese Input", "fcitx5-remote -t")

-- Omni Finder (Search Apps, Files & Folders)
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + ALT + SPACE", "Search Apps & Files", "omarchy-finder")

-- Advanced Displays shortcuts (replaces default Display panel)
hl.unbind("SUPER + CTRL + D")
o.bind("SUPER + CTRL + D", "Display", "omarchy-shell io.github.fluffet.display toggle")
o.bind("SUPER + CTRL + SHIFT + D", "Arrange displays", "omarchy-shell shell toggle io.github.fluffet.display")

-- Workspace Switcher (io.github.woogy7.workspaces)
local switcher = { id = "io.github.woogy7.workspaces", timer = nil, held = false }
local hold_mod = "ALT"
local hold_keys = ({ ALT = { "Alt_L", "Alt_R" }, SUPER = { "Super_L", "Super_R" } })[hold_mod]

local function switcher_send(action)
  hl.exec_cmd("omarchy-shell shell summon " .. switcher.id
    .. " '{\"action\":\"" .. action .. "\",\"modifier\":\"" .. hold_mod:lower() .. "\"}'")
end

-- Poll the compositor for the modifier release
local function switcher_watch_release()
  if switcher.held then return end
  switcher.held = true
  if switcher.timer then switcher.timer:set_enabled(false) end
  switcher.timer = hl.timer(function()
    if not switcher.held then return end
    local down = false
    for _, k in ipairs(hold_keys) do if hl.is_key_down(k) then down = true end end
    if not down then
      switcher.held = false
      if switcher.timer then switcher.timer:set_enabled(false) end
      switcher_send("commit")
    end
  end, { timeout = 25, type = "repeat" })
end

-- Plain picker on SUPER+TAB
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Workspace switcher", "omarchy-shell shell toggle " .. switcher.id)

-- Hold-to-switch on ALT+TAB
hl.unbind(hold_mod .. " + TAB")
hl.unbind(hold_mod .. " + SHIFT + TAB")
o.bind(hold_mod .. " + TAB", "Workspace switcher (next)", function()
  switcher_send(switcher.held and "next" or "open-next")
  switcher_watch_release()
end)
o.bind(hold_mod .. " + SHIFT + TAB", "Workspace switcher (previous)", function()
  switcher_send(switcher.held and "prev" or "open-prev")
  switcher_watch_release()
end)
