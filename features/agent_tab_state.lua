-- Show structured agent lifecycle state in tab titles.
local wezterm = require("wezterm")

local M = {}

local states = {
  completed = { symbol = "✓", color = "#b8bb26", priority = 1 },
  running = { symbol = "●", color = "#83a598", priority = 2 },
  failed = { symbol = "✗", color = "#fb4934", priority = 3 },
  attention = { symbol = "!", color = "#fabd2f", priority = 4 },
}

local function title_for_tab(tab)
  if tab.tab_title and #tab.tab_title > 0 then
    return tab.tab_title
  end

  return tab.active_pane.title
end

local function state_for_tab(tab)
  local selected

  -- A background split can need attention even when it is not the active pane.
  for _, pane in ipairs(tab.panes or { tab.active_pane }) do
    local state = states[(pane.user_vars or {}).agent_state]
    if state and (not selected or state.priority > selected.priority) then
      selected = state
    end
  end

  return selected
end

function M.apply(config)
  wezterm.on("format-tab-title", function(tab, _, _, effective_config, _, max_width)
    local title = title_for_tab(tab)
    local index = ""

    if effective_config.show_tab_index_in_tab_bar then
      index = tostring(tab.tab_index + 1) .. ": "
    end

    local state = state_for_tab(tab)
    local state_width = state and 2 or 0
    title = wezterm.truncate_right(index .. title, math.max(1, max_width - state_width - 2))

    if not state then
      return " " .. title .. " "
    end

    return {
      { Foreground = { Color = state.color } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " " .. state.symbol .. " " .. title .. " " },
    }
  end)
end

return M
