local wezterm = require("wezterm")
local config = wezterm.config_builder()
local agent_tab_state = require("features.agent_tab_state")
local color_scheme = require("features.color_scheme")
local tab_navigation = require("features.tab_navigation")

local features = {
  { module = color_scheme, enabled = true },
  { module = agent_tab_state, enabled = true },
  { module = tab_navigation, enabled = true },
}

for _, feature in ipairs(features) do
  if feature.enabled then
    feature.module.apply(config)
  end
end

return config
