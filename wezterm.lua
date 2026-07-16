local wezterm = require("wezterm")
local config = wezterm.config_builder()
local agent_tab_state = require("features.agent_tab_state")
local color_scheme = require("features.color_scheme")
local tab_navigation = require("features.tab_navigation")

local features = {
  color_scheme,
  agent_tab_state,
  tab_navigation,
}

for _, feature in ipairs(features) do
  feature.apply(config)
end

return config
