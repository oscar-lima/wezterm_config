-- Start the WezTerm GUI with two side-by-side panes.
local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

local M = {}

-- Set this to the percentage of the window that the left pane should occupy.
local left_pane_percentage = 70
local startup_pane_states = {}

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

local function normalize_startup_pane(window)
  for _, tab in ipairs(window:mux_window():tabs()) do
    local panes = tab:panes_with_info()

    if #panes == 1 then
      local left_pane_id = panes[1].pane:pane_id()

      if startup_pane_states[left_pane_id] == "pending" then
        startup_pane_states[left_pane_id] = "split"
        split_pane(panes[1].pane)
        return
      end
    elseif #panes == 2 and panes[1].top == panes[2].top then
      local left = panes[1].left < panes[2].left and panes[1] or panes[2]
      local right = panes[1].left < panes[2].left and panes[2] or panes[1]
      local left_pane_id = left.pane:pane_id()

      if startup_pane_states[left_pane_id] == "split" then
        local pane_columns = left.width + right.width
        local target_left_width = math.floor(pane_columns * left_pane_percentage / 100)
        local adjustment = target_left_width - left.width

        if adjustment > 0 then
          window:perform_action(act.AdjustPaneSize({ "Right", adjustment }), right.pane)
        elseif adjustment < 0 then
          window:perform_action(act.AdjustPaneSize({ "Left", -adjustment }), right.pane)
        else
          startup_pane_states[left_pane_id] = nil
        end

        return
      end
    end
  end
end

function M.apply(config)
  validate_left_pane_percentage()

  wezterm.on("gui-startup", function(command)
    local _, left_pane = mux.spawn_window(command or {})
    startup_pane_states[left_pane:pane_id()] = "pending"
  end)

  wezterm.on("window-resized", function(window)
    normalize_startup_pane(window)
  end)

  wezterm.on("update-status", function(window)
    normalize_startup_pane(window)
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
