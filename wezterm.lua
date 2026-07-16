local wezterm = require("wezterm")
local config = wezterm.config_builder()
local color_scheme = require("features.color_scheme")
local tab_navigation = require("features.tab_navigation")

local features = {
  color_scheme,
  tab_navigation,
}

for _, feature in ipairs(features) do
  feature.apply(config)
end

return config
