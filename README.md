# WezTerm Configuration

A modular WezTerm configuration with one Lua module per feature.

## Installation

Run the installer from any checkout location:

```bash
./install.sh
```

The script copies only the files needed at runtime to
`$XDG_CONFIG_HOME/wezterm` when `XDG_CONFIG_HOME` is set, or to
`~/.config/wezterm` otherwise. It installs the helper commands in
`~/.local/bin`. The installed configuration is self-contained, so the checkout
can then be moved or removed. Existing configuration and command files are
renamed with a timestamped `.backup-*` suffix before replacement.

To use non-default destinations, pass either or both options:

```bash
./install.sh --config-dir /path/to/wezterm-config --bin-dir /path/to/bin
```

Make sure `~/.local/bin` (or the selected `--bin-dir`) is on `PATH`. Re-run the
installer after changing this repository to refresh the installed copy.

Verify that WezTerm can see the entry point and load the configuration:

```bash
test -f ~/.config/wezterm/wezterm.lua
wezterm show-keys --lua | grep "mods = 'ALT'"
```

## Files and features

| File | Function added to WezTerm |
| --- | --- |
| `install.sh` | Installs a relocatable runtime copy of the configuration and its helper commands. |
| `wezterm.lua` | Builds the configuration and applies enabled feature modules in their listed order. |
| `features/window_backend.lua` | Runs WezTerm through its native Wayland backend to avoid XWayland redraw artifacts. |
| `features/color_scheme.lua` | Selects the `Gruvbox Dark (Gogh)` color scheme. |
| `features/text_cursor.lua` | Uses a steady bar cursor and disables cursor blinking to reduce distracting redraws. |
| `features/codex_notifications.lua` | Relays containerized Codex completion events to timed, clickable host notifications. |
| `features/initial_pane_layout.lua` | Starts the GUI and new tabs with consistently proportioned side-by-side panes and adds Alt+PageUp/PageDown navigation between them. |
| `features/pane_working_directory_sync.lua` | Keeps the right pane in the left pane's working directory whenever the right pane is at a shell prompt. |
| `features/scrollbar.lua` | Shows a green scrollbar in the right-side padding of each WezTerm window and retains up to 100,000 lines of scrollback per tab. |
| `features/tab_navigation.lua` | Adds Alt+Left/Right tab cycling and Alt+1–9 direct tab selection. |
| `features/tab_titles.lua` | Names tabs after the active pane's working directory, adds colored and focus-aware agent states, and provides attention-tab navigation. |
| `features/two_pane_tab_controls.lua` | Adds Ctrl+W closing of the current tab with both panes. |
| `bin/wezterm-agent-state` | Provides the low-level lifecycle interface used by agent integrations to publish pane state. |
| `bin/wezterm-tab-task` | Provides the manual `pending` and `done` tab-task interface. |
| `bin/codex-wezterm-notify` | Sends Codex completion events through the originating terminal and runs the host notification worker. |
| `integrations/claude-code-hooks.json` | Provides Claude Code lifecycle hooks for tab state. |
| `integrations/codex-hooks.toml` | Provides Codex lifecycle hooks for tab state. |
| `integrations/opencode-agent-state.js` | Provides an opencode plugin for tab state. |

## Window backend

WezTerm uses its native Wayland backend so its rendering path matches the
desktop session and avoids XWayland redraw artifacts.

## Text cursor

The text cursor is a steady bar rather than a blinking block. Cursor blinking
is disabled globally, including when an application requests a blinking cursor.

## Initial pane layout

Each new WezTerm GUI starts with two terminal panes arranged side by side. New
tabs opened with Ctrl+Shift+T, Super+T, or the tab-bar `+` button use the same
layout. Alt+PageUp focuses the pane to the left, and Alt+PageDown focuses the
pane to the right.

The initial GUI split is created on the first resize event, with the first
status update as a fallback. Its measured pane widths are then corrected to the
configured percentage after startup resizing finishes, matching later tabs.

Alt+Left/Right move between tabs. Alt+Shift+A jumps to the next tab that is
unread, failed, waiting for input, or manually pending. Pane focus remains on
Alt+PageUp/PageDown. Ctrl+W closes the current tab, including both panes that
belong to it.

Set `left_pane_percentage` near the top of
`features/initial_pane_layout.lua` to control the initial proportions. For
example, `50` gives both panes equal space. The configured value is `60`, giving
the left pane 60% and the right pane 40%. The value must be greater than `0` and
less than `100`.

The left pane is authoritative for the working directory. If its directory
changes, the right pane follows within about half a second once the right pane
is back at a Bash, Zsh, Fish, Dash, or POSIX shell prompt. A program running in
the right pane is not interrupted; synchronization resumes when it exits.

## Tab titles and agent state

Tab titles use the active pane's working-directory basename. A trailing `src`
directory is treated as a workspace marker, so `/path/to/example_ws/src` is
shown as `example_ws`. Tabs allow up to 40 cells so typical repository and
workspace names remain visible; WezTerm may still shorten them when the window
cannot fit all open tabs. While the active pane reports a running agent, its
live terminal title takes precedence so progress animations remain visible.

The same formatter reads an `agent_state` WezTerm user variable rather than
parsing terminal output. This gives agents and lifecycle hooks a stable,
tool-independent signaling mechanism:

| State | Tab indicator | Intended meaning |
| --- | --- | --- |
| `running` | blue `●` | The agent is working. |
| `completed` | pink `✓`, then green `✓` | The turn finished; pink remains until its tab is viewed. |
| `failed` | red `✗` | The turn or session failed. |
| `attention` | yellow `!` | The agent is waiting for input or permission. |
| `pending` | pink `◆` | A manually pinned task that remains pending even while focused. |
| `clear` | none | Remove the state from the pane. |

If a tab contains multiple panes, the most urgent pane state is shown. Manually
pinned pending work has the highest priority, followed by attention, failure,
running, unread completion, and acknowledged completion.

The installer makes the low-level helper, manual tab-task wrapper, and Codex
notification command available to agent hooks in `~/.local/bin`. The low-level
helper uses Ubuntu's standard `base64` utility and writes the OSC control
sequence directly to the controlling terminal, so hook frameworks may capture
their normal stdout without breaking the signal.

Agent integrations use the low-level lifecycle states:

```bash
wezterm-agent-state running
wezterm-agent-state completed
```

For manual task tracking, use only the wrapper:

```bash
wezterm-tab-task pending
wezterm-tab-task done
```

Manual `pending` displays a pinned pink `◆` that is not acknowledged by focus.
Manual `done` removes that marker. Internally, the wrapper delegates to
`wezterm-agent-state pending` and `wezterm-agent-state clear`, keeping terminal
signaling in one implementation without exposing lifecycle terminology in the
manual workflow. State is published by the current pane and aggregated into
its containing tab.

### Agent integrations

- Claude Code: merge `integrations/claude-code-hooks.json` into
  `~/.claude/settings.json`. It marks prompts as running, permission requests as
  needing attention, normal stops as completed, and API-error stops as failed.
- Codex: merge `integrations/codex-hooks.toml` into
  `~/.codex/config.toml`. Current hooks cover running, permission requests, and
  successful turn completion. The integration disables built-in TUI alerts and
  uses `bin/codex-wezterm-notify` exclusively for completed turns. Its
  notification request crosses Docker isolation through a WezTerm
  user variable, allowing the host configuration to identify the originating
  pane without exposing the WezTerm control socket to the container. The
  notification names the completed task from the submitted prompt, falling
  back to the originating working-directory name when no prompt is available,
  includes the final assistant message, and focuses the exact originating pane
  when clicked. Stable turn IDs suppress exact event replays, while a five-minute
  content fingerprint suppresses the same logical completion when Codex assigns
  it new IDs. The relay clears each request from the pane after delivery. Codex also invokes the
  legacy notifier when its hidden title-generation thread finishes near task
  startup. That thread has its own IDs, so duplicate filtering cannot suppress
  it. The relay recognizes Codex's internal title/rename prompt envelope and
  discards those events before terminal delivery or the desktop fallback.
  Ordinary user tasks that request titles or return JSON still notify. This
  compatibility filter is needed because the legacy notification payload does
  not include the thread's internal/ephemeral classification.
  The host worker explicitly closes the notification
  after 0.5 seconds when the originating tab is active and after 3 seconds
  otherwise, even when the desktop ignores its requested expiration timeout.
  Dismissing it does not change focus or acknowledge the pink tab indicator.
  The `codex-wezterm-notify` command must be available inside the environment
  where Codex runs; containerized Codex images should install their own copy.
  Use `wezterm-agent-state failed` manually or from an additional local hook
  when a surrounding workflow detects failure.
- opencode: copy `integrations/opencode-agent-state.js` to
  `~/.config/opencode/plugins/`. It uses documented session, permission, and
  tool events to cover all four states.

Run notification regression tests without sending desktop alerts:

```bash
python3 -B -m unittest discover -s tests -v
```

The tests cover the hidden title completion followed by the real task completion
on both delivery routes, ordinary title/JSON tasks, and terminal request clearing.
After a relay change, rerun `./install.sh`. For `codex-isolated`, also rebuild
using its repository's `./install.sh` and start a new isolated session; existing
containers retain the old image-installed relay.

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
  { module = window_backend, enabled = true },
  { module = color_scheme, enabled = true },
  { module = codex_notifications, enabled = true },
  { module = tab_titles, enabled = false },
  { module = initial_pane_layout, enabled = true },
  { module = pane_working_directory_sync, enabled = true },
  { module = scrollbar, enabled = true },
  { module = tab_navigation, enabled = true },
  { module = two_pane_tab_controls, enabled = true },
}
```

Set a feature to `false` to disable it, or back to `true` to enable it. Keep the
entries in their existing order unless a feature needs to run before another
one.
