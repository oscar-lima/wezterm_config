-- Relay Codex completion events to a timed, clickable host notification.
local wezterm = require("wezterm")

local M = {}

local notification_timeout_ms = 2000
local handled_requests = {}
local handled_request_order = {}
local max_handled_requests = 256

local function notification_request(value)
  if #value > 4096 then
    return nil
  end

  local success, request = pcall(wezterm.json_parse, value)
  if not success or type(request) ~= "table" then
    return nil
  end
  if type(request.id) ~= "string"
    or request.id == ""
    or type(request.summary) ~= "string"
    or type(request.body) ~= "string"
  then
    return nil
  end

  return request
end

function M.apply(_)
  wezterm.on("user-var-changed", function(_, pane, name, value)
    if name ~= "codex_notification_request" then
      return
    end

    local request = notification_request(value)
    if not request then
      return
    end

    local request_key = tostring(pane:pane_id()) .. ":" .. request.id
    if handled_requests[request_key] then
      return
    end
    handled_requests[request_key] = true
    table.insert(handled_request_order, request_key)
    if #handled_request_order > max_handled_requests then
      handled_requests[table.remove(handled_request_order, 1)] = nil
    end

    local timeout_ms = notification_timeout_ms
    local notifier = wezterm.config_dir .. "/bin/codex-wezterm-notify"
    local wezterm_cli = wezterm.executable_dir .. "/wezterm"

    wezterm.background_child_process({
      "python3",
      notifier,
      "--host-worker",
      request.summary,
      request.body,
      tostring(pane:pane_id()),
      tostring(timeout_ms),
      wezterm_cli,
    })
  end)
end

return M
