# WezTerm Configuration

A modular WezTerm configuration with one Lua module per feature.

## Installation

WezTerm loads its configuration directory from `~/.config/wezterm`. Link the
whole repository there so that `wezterm.lua` can import the feature modules:

```bash
rm -f ~/.wezterm.lua
mkdir -p ~/.config
ln -sfn ~/wezterm_config ~/.config/wezterm
```

The final command assumes this repository is located at `~/wezterm_config`.
Change the source path if you cloned it elsewhere.

## Files and features

| File | Function added to WezTerm |
| --- | --- |
| `wezterm.lua` | Builds the configuration and applies each feature module. |
| `features/color_scheme.lua` | Selects the `Gruvbox Dark (Gogh)` color scheme. |
| `features/tab_navigation.lua` | Adds Alt+Left/Right tab cycling and Alt+1–9 direct tab selection. |

## Adding a feature

Add one descriptively named Lua file under `features/`. The module must expose
an `apply(config)` function that changes only the settings needed by that
feature. Import it in the `features` table in `wezterm.lua`, then add its
filename and behavior to the table above.
