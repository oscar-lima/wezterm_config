-- Start the WezTerm GUI with two side-by-side panes.
local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

local M = {}

-- Set this to the percentage of the window that the left pane should occupy.
local left_pane_percentage = 70

local function validate_left_pane_percentage()
  assert(
    type(left_pane_percentage) == "number"
      and left_pane_percentage > 0
      and left_pane_percentage < 100,
    "left_pane_percentage must be a number greater than 0 and less than 100"
  )
end

local function split_pane(left_pane)
  -- pane:split sizes the new right pane, so use the percentage left over.
  left_pane:split({
    direction = "Right",
    size = (100 - left_pane_percentage) / 100,
  })

  -- Splitting activates the new right pane, so restore focus to the left.
  left_pane:activate()
end

local function spawn_tab_with_layout(window)
  local _, left_pane = window:mux_window():spawn_tab({})
  split_pane(left_pane)
end

function M.apply(config)
  validate_left_pane_percentage()

  wezterm.on("gui-startup", function(command)
    local _, left_pane = mux.spawn_window(command or {})
    split_pane(left_pane)
  end)

  wezterm.on("new-tab-button-click", function(window, _, button)
    if button == "Left" then
      spawn_tab_with_layout(window)
      return false
    end
  end)

  config.keys = config.keys or {}

  local new_tab_action = wezterm.action_callback(function(window)
    spawn_tab_with_layout(window)
  end)

  table.insert(config.keys, {
    key = "t",
    mods = "CTRL|SHIFT",
    action = new_tab_action,
  })

  table.insert(config.keys, {
    key = "t",
    mods = "SUPER",
    action = new_tab_action,
  })

  table.insert(config.keys, {
    key = "PageUp",
    mods = "ALT",
    action = act.ActivatePaneDirection("Left"),
  })

  table.insert(config.keys, {
    key = "PageDown",
    mods = "ALT",
    action = act.ActivatePaneDirection("Right"),
  })
end

return M
