# Repository rules

This repository contains a modular WezTerm configuration. Follow these rules
for every change.

## Structure

- Keep `wezterm.lua` as a small entry point that creates the WezTerm config,
  applies feature modules, and returns the config.
- Put each user-facing feature in its own Lua file under `features/`.
- Give every feature file a descriptive `snake_case.lua` name that indicates
  what it configures.
- Group settings in one file only when they form a single cohesive feature.
- Do not put unrelated settings or key bindings in the same feature file.

## Feature modules

- Return a module table that exposes `apply(config)`.
- Make `apply(config)` change only the settings owned by that feature.
- Preserve existing config values when extending list-like settings. For
  example, initialize `config.keys` only when it is absent and insert new
  bindings instead of replacing bindings owned by other modules.
- Keep module-local helpers and dependencies local to the feature file.
- Add brief comments where intent, indexes, or WezTerm behavior is not obvious.
- Avoid duplicated key bindings and conflicting ownership between modules.

Use this shape:

```lua
local M = {}

function M.apply(config)
  -- Configure one cohesive feature.
end

return M
```

If the feature needs the WezTerm API, require it inside that module:

```lua
local wezterm = require("wezterm")
```

## Registering features

- Add every new feature module to the `features` table in `wezterm.lua`.
- Use the module path that matches its file path, without the `.lua` suffix.
- Assign `require(...)` results to local variables before adding them to the
  `features` table. This avoids Lua 5.4 treating loader metadata as an extra
  table item when `require(...)` is the final table expression.
- Keep the feature order deliberate when one setting could depend on an
  earlier module.

## Documentation

- Document every Lua file in the top-level `README.md`.
- For each file, state the filename and the function or behavior it adds to
  WezTerm.
- Update installation instructions if the expected configuration path or
  symlink layout changes.
- When adding, removing, renaming, or changing a feature, update the README in
  the same change.

## Validation

- Check Lua syntax for every changed Lua file when a Lua checker is available.
- Start or reload WezTerm after structural changes and confirm that no config
  error is reported.
- Review the final diff for undocumented files, unrelated changes, and key
  binding conflicts.
