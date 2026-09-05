-- Name tabs after their working directory and show structured agent state.
local wezterm = require("wezterm")

local M = {}

local states = {
  completed = { symbol = "✓", color = "#b8bb26", priority = 1 },
  done = { symbol = "✓", color = "#928374", priority = 1 },
  unread = { symbol = "✓", color = "#d3869b", priority = 2 },
  running = { symbol = "●", color = "#83a598", priority = 3 },
  failed = { symbol = "✗", color = "#fb4934", priority = 4 },
  attention = { symbol = "!", color = "#fabd2f", priority = 5 },
  pending = { symbol = "◆", color = "#d3869b", priority = 6 },
}

-- Completion remains unread until its containing tab is viewed.
local unread_completed_panes = {}

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
  local active_pane = tab.active_pane
  local active_state = (active_pane.user_vars or {}).agent_state

  -- Running agents may animate the terminal title to show live progress.
  if active_state == "running" and active_pane.title and #active_pane.title > 0 then
    return active_pane.title
  end

  local cwd_title = title_from_working_directory(active_pane)
  if cwd_title and #cwd_title > 0 then
    return cwd_title
  end

  if tab.tab_title and #tab.tab_title > 0 then
    return tab.tab_title
  end

  return active_pane.title
end

local function state_for_tab(tab)
  local selected

  -- A background split can need attention even when it is not the active pane.
  for _, pane in ipairs(tab.panes or { tab.active_pane }) do
    local pane_id = pane.pane_id
    local state_name = (pane.user_vars or {}).agent_state
    if state_name == "completed" and unread_completed_panes[pane_id] then
      state_name = "unread"
    end

    local state = states[state_name]
    if state and (not selected or state.priority > selected.priority) then
      selected = state
    end
  end

  return selected
end

local function tab_contains_pane(tab, pane_id)
  for _, pane in ipairs(tab:panes()) do
    if pane:pane_id() == pane_id then
      return true
    end
  end

  return false
end

local function acknowledge_active_tab(window)
  if not window:is_focused() then
    return
  end

  for _, pane in ipairs(window:active_tab():panes()) do
    if pane:get_user_vars().agent_state == "completed" then
      unread_completed_panes[pane:pane_id()] = nil
    end
  end
end

local function pane_needs_attention(pane)
  local state_name = pane:get_user_vars().agent_state
  return state_name == "pending"
    or state_name == "attention"
    or state_name == "failed"
    or (state_name == "completed" and unread_completed_panes[pane:pane_id()])
end

local function tab_needs_attention(tab)
  for _, pane in ipairs(tab:panes()) do
    if pane_needs_attention(pane) then
      return true
    end
  end

  return false
end

local function activate_next_attention_tab(window)
  local tabs = window:mux_window():tabs_with_info()
  local active_index = 1

  for index, info in ipairs(tabs) do
    if info.is_active then
      active_index = index
      break
    end
  end

  -- Start after the current tab and wrap once through the window.
  for offset = 1, #tabs do
    local index = ((active_index - 1 + offset) % #tabs) + 1
    if tab_needs_attention(tabs[index].tab) then
      tabs[index].tab:active_pane():activate()
      return
    end
  end
end

function M.apply(config)
  -- The default limit is 16 cells, which truncates typical repository names.
  config.tab_max_width = 40
  config.keys = config.keys or {}

  wezterm.on("user-var-changed", function(window, pane, name, value)
    if name == "agent_focus_request" then
      -- Notification clicks arrive through the originating pane's terminal.
      pane:activate()
      window:focus()
      return
    end

    if name ~= "agent_state" then
      return
    end

    local pane_id = pane:pane_id()
    if value == "completed" then
      local active_tab = window:active_tab()
      local is_being_viewed = window:is_focused() and tab_contains_pane(active_tab, pane_id)
      unread_completed_panes[pane_id] = not is_being_viewed or nil
    else
      unread_completed_panes[pane_id] = nil
    end
  end)

  wezterm.on("update-status", function(window)
    acknowledge_active_tab(window)
  end)

  table.insert(config.keys, {
    key = "a",
    mods = "ALT|SHIFT",
    action = wezterm.action_callback(function(window)
      activate_next_attention_tab(window)
    end),
  })

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
