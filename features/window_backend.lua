-- Select the window backend for the detected desktop session.
-- Wayland sessions: native Wayland avoids the text redraw flicker reproduced
-- under XWayland. X11 sessions: WezTerm is a plain X11 client, so native
-- Wayland is explicitly off rather than left to WezTerm's default.
-- Keep scrollbar fixes in their own module instead of changing this backend.
local display_session = require("features.display_session")

local M = {}

function M.apply(config)
  config.enable_wayland = display_session.is_wayland()
end

return M
