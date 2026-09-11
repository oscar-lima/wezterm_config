-- Match the native display protocol to avoid XWayland redraw artifacts.
local M = {}

function M.apply(config)
  config.enable_wayland = true
end

return M
