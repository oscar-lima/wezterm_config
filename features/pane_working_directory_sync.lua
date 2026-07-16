-- Keep the right pane's working directory synchronized with the left pane.
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

local function horizontal_pair(tab)
  local panes = tab:panes_with_info()

  -- Only synchronize tabs that still have the configured two-pane layout.
  if #panes ~= 2 or panes[1].top ~= panes[2].top then
    return nil, nil
  end

  if panes[1].left < panes[2].left then
    return panes[1].pane, panes[2].pane
  end
  return panes[2].pane, panes[1].pane
end

local function synchronize_tab(tab)
  local left_pane, right_pane = horizontal_pair(tab)

  if not left_pane then
    return
  end

  local left_cwd = file_path_for_pane(left_pane)
  local right_cwd = file_path_for_pane(right_pane)
  local right_pane_id = right_pane:pane_id()

  if not left_cwd or left_cwd == right_cwd then
    pending_directories[right_pane_id] = nil
    return
  end

  if pending_directories[right_pane_id] == left_cwd or not is_idle_shell(right_pane) then
    return
  end

  -- Ctrl+U clears any unsubmitted input before changing directory.
  right_pane:send_text("\x15cd -- " .. shell_quote(left_cwd) .. "\n")
  pending_directories[right_pane_id] = left_cwd
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
