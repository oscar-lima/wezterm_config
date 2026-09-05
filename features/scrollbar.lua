-- Show a scrollbar in the right-side window padding.
local M = {}

function M.apply(config)
  config.enable_scroll_bar = true
  config.scrollback_lines = 100000

  config.colors = config.colors or {}
  config.colors.scrollbar_thumb = "#b8bb26"
end

return M
