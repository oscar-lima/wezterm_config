-- Use the WebGPU renderer tested with the native Wayland window backend.
local M = {}

function M.apply(config)
  config.front_end = "WebGpu"
end

return M
