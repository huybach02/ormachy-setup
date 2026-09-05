-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Screenshot shortcut (Windows-like Super+Shift+S)
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")

-- Clipboard history (Windows-like Super+V)
hl.unbind("SUPER + V")
o.bind("SUPER + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
