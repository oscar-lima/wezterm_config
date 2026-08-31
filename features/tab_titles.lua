-- Name tabs after their working directory and show structured agent state.
local wezterm = require("wezterm")

local M = {}

local states = {
  completed = { symbol = "✓", color = "#b8bb26", priority = 1 },
  running = { symbol = "●", color = "#83a598", priority = 2 },
  failed = { symbol = "✗", color = "#fb4934", priority = 3 },
  attention = { symbol = "!", color = "#fabd2f", priority = 4 },
}

local function basename(path)
  local without_trailing_separator = path:gsub("[/\\]+$", "")
  return without_trailing_separator:match("([^/\\]+)$"), without_trailing_separator
end

local function title_from_working_directory(pane)
  local cwd = pane.current_working_dir
  if not cwd or cwd.scheme ~= "file" then
    return nil
  end

  local name, path = basename(cwd.file_path)
  if name == "src" then
    -- A trailing src denotes a workspace; display the workspace directory.
    name = basename(path:sub(1, #path - #name))
  end

  return name
end

local function title_for_tab(tab)
  local cwd_title = title_from_working_directory(tab.active_pane)
  if cwd_title and #cwd_title > 0 then
    return cwd_title
  end

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
  -- The default limit is 16 cells, which truncates typical repository names.
  config.tab_max_width = 40

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
