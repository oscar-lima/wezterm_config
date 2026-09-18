-- Detect whether the GUI runs inside a Wayland or X11 desktop session so that
-- other features can pick backend-specific settings without hard-coding one.
-- This module is a helper only: it exposes no apply(config) and is not listed
-- in the wezterm.lua features table.
local M = {}

-- Returns "wayland" or "x11". XDG_SESSION_TYPE is set by the login manager and
-- reflects the real session even when WAYLAND_DISPLAY leaks into an X11 shell.
-- Anything unknown falls back to X11, the more widely supported backend.
function M.detect()
  local session_type = os.getenv("XDG_SESSION_TYPE")
  if session_type == "wayland" then
    return "wayland"
  elseif session_type == "x11" then
    return "x11"
  end

  local wayland_display = os.getenv("WAYLAND_DISPLAY")
  if wayland_display and wayland_display ~= "" then
    return "wayland"
  end
  return "x11"
end

function M.is_wayland()
  return M.detect() == "wayland"
end

return M
