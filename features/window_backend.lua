-- Native Wayland avoids the text redraw flicker reproduced under XWayland.
-- Keep scrollbar fixes in their own module instead of changing this backend.
local M = {}

function M.apply(config)
  config.enable_wayland = true
end

return M
