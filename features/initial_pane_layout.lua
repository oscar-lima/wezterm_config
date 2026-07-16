-- Start the WezTerm GUI with two side-by-side panes.
local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

local M = {}

-- Set this to the percentage of the window that the left pane should occupy.
local left_pane_percentage = 70
local startup_split_delay_seconds = 0.1
local pending_startup_pane_ids = {}

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

local function split_pending_startup_panes()
  local pane_ids = pending_startup_pane_ids
  pending_startup_pane_ids = {}

  wezterm.time.call_after(startup_split_delay_seconds, function()
    for _, pane_id in ipairs(pane_ids) do
      local left_pane = mux.get_pane(pane_id)
      local tab = left_pane and left_pane:tab()

      -- Wait for final GUI dimensions, and avoid duplicating a user-created split.
      if tab and #tab:panes() == 1 then
        split_pane(left_pane)
      end
    end
  end)
end

function M.apply(config)
  validate_left_pane_percentage()

  wezterm.on("gui-startup", function(command)
    local _, left_pane = mux.spawn_window(command or {})
    table.insert(pending_startup_pane_ids, left_pane:pane_id())
  end)

  wezterm.on("gui-attached", function()
    if #pending_startup_pane_ids > 0 then
      split_pending_startup_panes()
    end
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
