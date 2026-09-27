-- Keep the right panes' working directories synchronized with the left pane.
local wezterm = require("wezterm")

local M = {}

local pending_directories = {}
local supported_shells = {
  bash = true,
  dash = true,
  fish = true,
  sh = true,
  zsh = true,
}

local function basename(path)
  return path and path:match("([^/\\]+)$") or nil
end

local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function normalize_path(path)
  if path == "/" then
    return path
  end

  -- WezTerm may report the same directory with or without trailing slashes.
  return path:gsub("[/\\]+$", "")
end

local function file_path_for_pane(pane)
  local cwd = pane:get_current_working_dir()

  if not cwd or cwd.scheme ~= "file" then
    return nil
  end

  return normalize_path(cwd.file_path)
end

local function is_idle_shell(pane)
  return supported_shells[basename(pane:get_foreground_process_name())] or false
end

local function layout_panes(tab)
  local panes = tab:panes_with_info()

  -- Leave manually rearranged tabs alone.
  if #panes ~= 4 then
    return nil
  end

  table.sort(panes, function(a, b)
    return a.left < b.left or (a.left == b.left and a.top < b.top)
  end)
  local left = panes[1]
  if panes[2].left <= left.left or panes[2].left ~= panes[3].left
      or panes[3].left ~= panes[4].left then
    return nil
  end
  return left.pane, { panes[2].pane, panes[3].pane, panes[4].pane }
end

local function synchronize_tab(tab)
  local left_pane, right_panes = layout_panes(tab)

  if not left_pane then
    return
  end

  local left_cwd = file_path_for_pane(left_pane)
  if not left_cwd then
    return
  end

  for _, right_pane in ipairs(right_panes) do
    local right_pane_id = right_pane:pane_id()
    if left_cwd == file_path_for_pane(right_pane) then
      pending_directories[right_pane_id] = nil
    elseif pending_directories[right_pane_id] ~= left_cwd and is_idle_shell(right_pane) then
      -- Ctrl+U clears any unsubmitted input before changing directory.
      right_pane:send_text("\x15cd -- " .. shell_quote(left_cwd) .. "\n")
      pending_directories[right_pane_id] = left_cwd
    end
  end
end

function M.apply(config)
  -- Poll often enough that the right pane follows shortly after the left prompt returns.
  config.status_update_interval = 500

  wezterm.on("update-status", function(window)
    for _, tab in ipairs(window:mux_window():tabs()) do
      synchronize_tab(tab)
    end
  end)
end

return M
