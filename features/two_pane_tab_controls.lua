-- Close the current tab with a single shortcut.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.apply(config)
  config.keys = config.keys or {}

  table.insert(config.keys, {
    key = "w",
    mods = "CTRL",
    -- Close the tab container so that both panes are closed together.
    action = act.CloseCurrentTab({ confirm = false }),
  })
end

return M
