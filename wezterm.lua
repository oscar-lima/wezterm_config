local wezterm = require("wezterm")
local config = wezterm.config_builder()
local color_scheme = require("features.color_scheme")
local codex_notifications = require("features.codex_notifications")
local initial_pane_layout = require("features.initial_pane_layout")
local pane_working_directory_sync = require("features.pane_working_directory_sync")
local scrollbar = require("features.scrollbar")
local tab_navigation = require("features.tab_navigation")
local tab_titles = require("features.tab_titles")
local text_cursor = require("features.text_cursor")
local two_pane_tab_controls = require("features.two_pane_tab_controls")
local window_backend = require("features.window_backend")

local features = {
  { module = window_backend, enabled = true },
  { module = color_scheme, enabled = true },
  { module = text_cursor, enabled = true },
  { module = codex_notifications, enabled = true },
  { module = tab_titles, enabled = true },
  { module = initial_pane_layout, enabled = true },
  { module = pane_working_directory_sync, enabled = true },
  { module = scrollbar, enabled = true },
  { module = tab_navigation, enabled = true },
  { module = two_pane_tab_controls, enabled = true },
}

for _, feature in ipairs(features) do
  if feature.enabled then
    feature.module.apply(config)
  end
end

return config
