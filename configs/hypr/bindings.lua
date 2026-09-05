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

