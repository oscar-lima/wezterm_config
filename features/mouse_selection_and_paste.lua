-- Keep plain-mouse text selection and middle-click paste working inside
-- applications that capture the mouse (opencode, vim with mouse=a, ...).
--
-- Once an application enables mouse reporting, WezTerm forwards every mouse
-- event to it: plain drag no longer selects, double-click no longer selects a
-- word, and middle-click never reaches PasteFrom. opencode then does its own
-- selection and copies it to the clipboard, so a middle-click pastes a stale
-- primary selection instead of what was just selected.
--
-- These bindings mirror WezTerm's default left/middle button behavior and
-- set `mouse_reporting = true`, so they win over the application. The wheel
-- and modifier+click combinations are left unbound here and still reach the
-- application (Ctrl+click for its own click handling, wheel for scrolling).
local wezterm = require("wezterm")
local act = wezterm.action
local M = {}

local function binding(event, action)
  return {
    event = event,
    mods = "NONE",
    mouse_reporting = true,
    action = action,
  }
end

function M.apply(config)
  config.mouse_bindings = config.mouse_bindings or {}
  local bindings = {
    -- Single click / drag selects by cell, double by word, triple by line.
    binding({ Down = { streak = 1, button = "Left" } }, act.SelectTextAtMouseCursor("Cell")),
    binding({ Down = { streak = 2, button = "Left" } }, act.SelectTextAtMouseCursor("Word")),
    binding({ Down = { streak = 3, button = "Left" } }, act.SelectTextAtMouseCursor("Line")),
    binding({ Drag = { streak = 1, button = "Left" } }, act.ExtendSelectionToMouseCursor("Cell")),
    binding({ Drag = { streak = 2, button = "Left" } }, act.ExtendSelectionToMouseCursor("Word")),
    binding({ Drag = { streak = 3, button = "Left" } }, act.ExtendSelectionToMouseCursor("Line")),
    -- Releasing copies to the primary selection (and opens a clicked link).
    binding({ Up = { streak = 1, button = "Left" } }, act.CompleteSelectionOrOpenLinkAtMouseCursor("PrimarySelection")),
    binding({ Up = { streak = 2, button = "Left" } }, act.CompleteSelection("PrimarySelection")),
    binding({ Up = { streak = 3, button = "Left" } }, act.CompleteSelection("PrimarySelection")),
    -- Middle-click pastes the primary selection.
    binding({ Down = { streak = 1, button = "Middle" } }, act.PasteFrom("PrimarySelection")),
  }
  for _, b in ipairs(bindings) do
    table.insert(config.mouse_bindings, b)
  end
end

return M
