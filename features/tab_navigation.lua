-- Add keyboard shortcuts for moving between and directly selecting tabs.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.apply(config)
  config.keys = config.keys or {}

  table.insert(config.keys, {
    key = "LeftArrow",
    mods = "ALT",
    action = act.ActivateTabRelative(-1),
  })

  table.insert(config.keys, {
    key = "RightArrow",
    mods = "ALT",
    action = act.ActivateTabRelative(1),
  })

  -- Alt+1 selects the first tab, Alt+2 the second, and so on.
  -- WezTerm tab indexes start at zero.
  for number = 1, 9 do
    table.insert(config.keys, {
      key = tostring(number),
      mods = "ALT",
      action = act.ActivateTab(number - 1),
    })
  end
end

return M
