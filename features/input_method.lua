-- Select the input method integration for the detected desktop session.
-- X11 sessions (#302, root cause read in the WezTerm 20240203 source; current
-- main is the same): WezTerm always creates its XIM client, and on every
-- focus-in, resize and text-cursor move while focused it asks it to update the
-- cursor position. Without an open input context that starts a new XIM
-- connection (xcb_xim_open), which creates a 1x1 window on the X root and asks
-- the input method (ibus) for its transport. With use_ime = false WezTerm never
-- hands the client the answer, so the connection never completes, the window is
-- never destroyed, and the next update starts again: one leaked root window per
-- focus change or cursor move, tens of thousands overnight, which froze
-- docking, undocking and suspend. The XIM client is made when WezTerm starts:
-- this takes effect in a new WezTerm process, not on a config reload. use_ime =
-- false alone therefore does not help. xim_im_name = "@im=none" names an XIM
-- server that does not exist, so the client finds none and opens nothing (the
-- same as XMODIFIERS=@im=none, but for WezTerm only and on every launch path;
-- keep the "@im=" prefix: "none" alone would match any server).
-- Wayland sessions: text-input-v3 does not use XIM and shows no leak, so the
-- IME stays enabled there.
-- Without XIM, ibus input methods do not work inside WezTerm on X11; compose
-- and dead-key sequences still do (WezTerm reads the xkb compose tables itself).
local display_session = require("features.display_session")

local M = {}

function M.apply(config)
  -- true is WezTerm's default; it is set explicitly so the Wayland behavior
  -- does not silently change if that default ever moves.
  config.use_ime = display_session.is_wayland()
  if not display_session.is_wayland() then
    config.xim_im_name = "@im=none"
  end
end

return M
