-- Start the WezTerm GUI with a left pane and three stacked right panes.
local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

local M = {}

-- Set this to the percentage of the window that the left pane should occupy.
local left_pane_percentage = 60
-- Empty lists launch the normal shell. Use argv lists such as { "htop" }.
local top_pane_program = {}
local middle_pane_program = {}
local startup_pane_states = {}

local function validate_left_pane_percentage()
  assert(
    type(left_pane_percentage) == "number"
      and left_pane_percentage > 0
      and left_pane_percentage < 100,
    "left_pane_percentage must be a number greater than 0 and less than 100"
  )
end

local function program_args(program)
  return #program > 0 and program or nil
end

local function split_pane(left_pane)
  -- The original right pane becomes the middle; new splits fill its edges.
  local middle_pane = left_pane:split({
    direction = "Right",
    size = (100 - left_pane_percentage) / 100,
    args = program_args(middle_pane_program),
  })
  middle_pane:split({ direction = "Bottom", size = 0.2 })
  middle_pane:split({
    direction = "Top",
    size = 0.25, -- 25% of the remaining 80% is 20% of the right column.
    args = program_args(top_pane_program),
  })

  -- Splitting activates the new top pane, so restore focus to the left.
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
    elseif #panes == 4 then
      local left, right
      for _, pane in ipairs(panes) do
        if not left or pane.left < left.left then
          left = pane
        end
      end
      for _, pane in ipairs(panes) do
        if pane.left > left.left then
          right = pane
          break
        end
      end
      local left_pane_id = left.pane:pane_id()

      if right and startup_pane_states[left_pane_id] == "split" then
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
