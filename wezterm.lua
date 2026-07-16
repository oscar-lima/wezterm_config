local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

-- config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = "Dracula"
config.color_scheme = "Gruvbox Dark (Gogh)"
-- config.color_scheme = "Tokyo Night"
-- config.color_scheme = "Nord"
-- config.color_scheme = "Solarized Dark (Gogh)"

config.keys = {
  {
    key = "LeftArrow",
    mods = "ALT",
    action = act.ActivateTabRelative(-1),
  },
  {
    key = "RightArrow",
    mods = "ALT",
    action = act.ActivateTabRelative(1),
  },
}

-- Alt+1 selects the first tab, Alt+2 the second, and so on.
-- WezTerm tab indexes start at zero.
for number = 1, 9 do
  table.insert(config.keys, {
    key = tostring(number),
    mods = "ALT",
    action = act.ActivateTab(number - 1),
  })
end

return config
