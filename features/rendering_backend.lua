-- Try a different GPU rendering path for text redraw artifacts under XWayland.
local M = {}

function M.apply(config)
  config.front_end = "WebGpu"
end

return M
