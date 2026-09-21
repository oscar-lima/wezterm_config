-- Keep middle-click paste working inside apps that capture the mouse
-- (opencode, vim with mouse=a, ...). By default WezTerm forwards every
-- mouse event to such apps, so middle-click never reaches PasteFrom.
local wezterm = require("wezterm")
local M = {}

function M.apply(config)
  config.mouse_bindings = config.mouse_bindings or {}
  for _, mouse_reporting in ipairs({ false, true }) do
    table.insert(config.mouse_bindings, {
      event = { Down = { streak = 1, button = "Middle" } },
      mods = "NONE",
      mouse_reporting = mouse_reporting,
      action = wezterm.action.PasteFrom("PrimarySelection"),
    })
  end
end

return M
