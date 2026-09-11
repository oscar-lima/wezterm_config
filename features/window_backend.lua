-- Use XWayland to retain native title-bar window controls.
local M = {}

function M.apply(config)
  config.enable_wayland = false
end

return M
