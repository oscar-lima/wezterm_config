# WezTerm Configuration

A modular WezTerm configuration with one Lua module per feature.

## Installation

WezTerm loads its configuration directory from `~/.config/wezterm`. Link the
whole repository there so that `wezterm.lua` can import the feature modules:

```bash
rm -f ~/.wezterm.lua
mkdir -p ~/.config

# Back up an existing config path. This also avoids ln placing the repository
# symlink inside an existing ~/.config/wezterm directory.
if [ -e ~/.config/wezterm ] || [ -L ~/.config/wezterm ]; then
  mv ~/.config/wezterm ~/.config/wezterm.backup-$(date +%Y%m%d-%H%M%S)
fi

ln -s ~/wezterm_config ~/.config/wezterm
```

The final command assumes this repository is located at `~/wezterm_config`.
Change the source path if you cloned it elsewhere. For this checkout, use:

```bash
ln -s /home/oscar/repos_cloned/wezterm_config ~/.config/wezterm
```

Verify that WezTerm can see the entry point and that the configuration directory
itself, rather than a child within it, is the symlink:

```bash
readlink -f ~/.config/wezterm
test -f ~/.config/wezterm/wezterm.lua
wezterm show-keys --lua | grep "mods = 'ALT'"
```

## Files and features

| File | Function added to WezTerm |
| --- | --- |
| `wezterm.lua` | Builds the configuration and applies enabled feature modules in their listed order. |
| `features/agent_tab_state.lua` | Adds colored tab-title indicators for structured agent lifecycle state. |
| `features/color_scheme.lua` | Selects the `Gruvbox Dark (Gogh)` color scheme. |
| `features/tab_navigation.lua` | Adds Alt+Left/Right tab cycling and Alt+1–9 direct tab selection. |
| `bin/wezterm-agent-state` | Publishes an agent state to the current pane using a WezTerm user variable. |
| `integrations/claude-code-hooks.json` | Provides Claude Code lifecycle hooks for tab state. |
| `integrations/codex-hooks.toml` | Provides Codex lifecycle hooks for tab state. |
| `integrations/opencode-agent-state.js` | Provides an opencode plugin for tab state. |

## Agent state in tabs

The tab formatter reads an `agent_state` WezTerm user variable rather than
parsing terminal output. This gives agents and lifecycle hooks a stable,
tool-independent signaling mechanism:

| State | Tab indicator | Intended meaning |
| --- | --- | --- |
| `running` | blue `●` | The agent is working. |
| `completed` | green `✓` | The turn finished successfully. |
| `failed` | red `✗` | The turn or session failed. |
| `attention` | yellow `!` | The agent is waiting for input or permission. |
| `clear` | none | Remove the state from the pane. |

If a tab contains multiple panes, the most urgent pane state is shown. The
priority is attention, failed, running, then completed.

Make the helper available to agent hooks:

```bash
mkdir -p ~/.local/bin
ln -sfn ~/.config/wezterm/bin/wezterm-agent-state ~/.local/bin/wezterm-agent-state
```

This assumes `~/.local/bin` is on `PATH`. The helper uses Ubuntu's standard
`base64` utility and writes the OSC control sequence directly to the controlling
terminal, so hook frameworks may capture their normal stdout without breaking
the signal. You can test it manually:

```bash
wezterm-agent-state running
wezterm-agent-state completed
wezterm-agent-state clear
```

### Agent integrations

- Claude Code: merge `integrations/claude-code-hooks.json` into
  `~/.claude/settings.json`. It marks prompts as running, permission requests as
  needing attention, normal stops as completed, and API-error stops as failed.
- Codex: merge `integrations/codex-hooks.toml` into
  `~/.codex/config.toml`. Current hooks cover running, permission requests, and
  successful turn completion. Use `wezterm-agent-state failed` manually or from
  an additional local hook when a surrounding workflow detects failure.
- opencode: copy `integrations/opencode-agent-state.js` to
  `~/.config/opencode/plugins/`. It uses documented session, permission, and
  tool events to cover all four states.

The integration files expect `wezterm-agent-state` on `PATH`. They are examples
to merge with existing settings rather than replacements for those files.

When using tmux, enable passthrough so the user-variable sequence reaches
WezTerm:

```tmux
set -g allow-passthrough on
```

## Adding a feature

Add one descriptively named Lua file under `features/`. The module must expose
an `apply(config)` function that changes only the settings needed by that
feature. Import it in `wezterm.lua`, add it to the `features` table with an
`enabled` flag, then add its filename and behavior to the table above.

## Enabling and disabling features

Each entry in the ordered `features` table in `wezterm.lua` has an `enabled`
flag:

```lua
local features = {
  { module = color_scheme, enabled = true },
  { module = agent_tab_state, enabled = false },
  { module = tab_navigation, enabled = true },
}
```

Set a feature to `false` to disable it, or back to `true` to enable it. Keep the
entries in their existing order unless a feature needs to run before another
one.
