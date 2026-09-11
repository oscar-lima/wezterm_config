-- Use XWayland because WezTerm's native Wayland path does not reliably render
-- window-edge UI such as the scrollbar on Ubuntu.
local M = {}

function M.apply(config)
  config.enable_wayland = false
end

return M
