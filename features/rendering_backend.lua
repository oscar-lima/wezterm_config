-- Select the renderer for the detected desktop session.
-- Wayland sessions: WebGPU is the renderer tested with native Wayland and the
-- XWayland typing-flicker workaround. X11 sessions: WebGPU (Vulkan on NVIDIA)
-- left a stale, non-interactive ghost of the window after minimizing under
-- GNOME on Xorg, so the default OpenGL renderer is used there.
local display_session = require("features.display_session")

local M = {}

function M.apply(config)
  if display_session.is_wayland() then
    config.front_end = "WebGpu"
  else
    config.front_end = "OpenGL"
  end
end

return M
