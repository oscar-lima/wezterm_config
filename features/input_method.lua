-- Select the input method integration for the detected desktop session.
-- X11 sessions: the XIM bridge leaks windows. With an input method running
-- (XMODIFIERS=@im=ibus), WezTerm opens an XIM context per pane and neither
-- WezTerm nor ibus-x11 destroys the 1x1 helper windows it creates, so both
-- accumulate children of the X root window (measured at ~2500 per hour).
-- Xorg then walks that list in miMarkOverlappedWindows on every screen-size
-- change, which froze the desktop for minutes when docking, undocking, or
-- opening the laptop lid. Wayland sessions: text-input-v3 does not use XIM
-- and shows no leak, so the IME stays enabled there.
-- Turning the IME off also disables compose and dead-key sequences inside
-- WezTerm; keyboard layouts that produce characters directly are unaffected.
local display_session = require("features.display_session")

local M = {}

function M.apply(config)
  -- true is WezTerm's default; it is set explicitly so the Wayland behavior
  -- does not silently change if that default ever moves.
  config.use_ime = display_session.is_wayland()
end

return M
