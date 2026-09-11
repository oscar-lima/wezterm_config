-- Keep the text cursor narrow and still to avoid distracting redraws.
local M = {}

function M.apply(config)
  config.default_cursor_style = "SteadyBar"
  -- Also disables blinking requested through terminal escape sequences.
  config.cursor_blink_rate = 0
end

return M
