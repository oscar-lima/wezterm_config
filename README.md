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
`~/.local/bin` and the opencode agent-state plugin in
`~/.config/opencode/plugins/`. The installed configuration is
self-contained, so the checkout can then be moved or removed. Existing
configuration and command files are renamed with a timestamped `.backup-*`
suffix before replacement.

On Linux, it also installs `org.wezfurlong.wezterm.desktop` in
`${XDG_DATA_HOME:-~/.local/share}/applications`. This user launcher overrides
the system WezTerm launcher and explicitly selects the installed configuration
with `--config-file` and starts a fresh GUI with `--always-new-process`.
Each launch from the app menu or dock opens an independent GUI process. An
existing user launcher is backed up before replacement. Custom `--config-dir`
destinations are also recorded in this launcher as absolute paths.

To use non-default destinations, pass either or all of these options:

```bash
./install.sh --config-dir /path/to/wezterm-config --bin-dir /path/to/bin \
  --opencode-plugins-dir /path/to/opencode-plugins
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
| `install.sh` | Installs a relocatable runtime copy, helper commands, the opencode agent-state plugin, and a Linux desktop launcher that starts a fresh GUI with the installed configuration. |
| `wezterm.lua` | Builds the configuration and applies enabled feature modules in their listed order. |
| `features/display_session.lua` | Helper (no `apply`) that detects whether the desktop session is Wayland or X11 so other features can branch on it. |
| `features/window_backend.lua` | Enables native Wayland in Wayland sessions (avoids the XWayland text redraw flicker) and disables it explicitly in X11 sessions. |
| `features/rendering_backend.lua` | Selects WebGPU in Wayland sessions and OpenGL in X11 sessions, where WebGPU left a stale window ghost after minimizing. |
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

## Display session detection

The configuration must work in both Wayland and X11 desktop sessions, because
the session type changes over time on the affected machine. `features/display_session.lua`
reads `XDG_SESSION_TYPE` (falling back to `WAYLAND_DISPLAY`, then X11) and
backend-sensitive features branch on its result rather than assuming one
session type. Check what a running window detected with:

```bash
for p in $(pgrep wezterm-gui); do tr '\0' '\n' < /proc/$p/environ | grep -E '^(XDG_SESSION_TYPE|WAYLAND_DISPLAY)='; done
```

## Window backend

In Wayland sessions WezTerm enables its native Wayland backend
(`enable_wayland = true`). On the affected NVIDIA/GNOME desktop, text
disappeared and reappeared while typing in terminal applications under
XWayland. Running the same affected application with native Wayland stopped the
observed flicker, and the green scrollbar was confirmed usable in that same
window. Plain shell typing was stable in both cases.

In X11 sessions (GNOME on Xorg) `enable_wayland` is set to `false` explicitly;
WezTerm is then a plain X11 client and the XWayland flicker does not apply.

The earlier native-Wayland fix (`3d5cf4d`) was undone by the scrollbar workaround
(`5233ad6`). Keep native Wayland enabled for Wayland sessions and address any
scrollbar problems in `features/scrollbar.lua` separately, so that a scrollbar
change does not restore the flickering backend. See WezTerm's
[Wayland option documentation](https://wezterm.org/config/lua/config/enable_wayland.html).

## Rendering backend, typing flicker, and minimize ghost

Wayland sessions use `WebGpu`, as used in the successful native-Wayland test.
WebGPU alone did not resolve the flicker while XWayland remained enabled.

X11 sessions use `OpenGL`. With `WebGpu` (Vulkan on the NVIDIA driver) under
GNOME on Xorg, minimizing WezTerm left a stale, non-interactive ghost of the
window on screen until it was restored from the dock. OpenGL is the renderer to
use there. See WezTerm's
[renderer documentation](https://wezterm.org/config/lua/config/front_end.html).

From this checkout, test the configuration in a separate GUI process before
installing it:

```bash
wezterm --config-file "$PWD/wezterm.lua" start --always-new-process
```

Check typing in both the shell and the application that flickered, check that
the scrollbar still renders, and minimize and restore the window. If it works,
run `./install.sh`, then open WezTerm from the app menu or dock. The installed
launcher uses the same explicit configuration and fresh-process options;
existing windows keep their running work. Renderer and window-backend changes
need a new process; reloading alone is insufficient.

To test the installed configuration directly:

```bash
wezterm --config-file "$HOME/.config/wezterm/wezterm.lua" start --always-new-process
```

To compare the other renderer in the same checkout without editing or
installing anything:

```bash
wezterm --config-file "$PWD/wezterm.lua" --config 'front_end="WebGpu"' start --always-new-process
```

To simulate the other session type's settings without logging out, override the
detected session (the window still runs on the current display server):

```bash
XDG_SESSION_TYPE=wayland wezterm --config-file "$PWD/wezterm.lua" start --always-new-process
```

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
cannot fit all open tabs. Terminal title updates from running programs are
ignored whenever a working-directory title is available, so agents such as
Codex cannot rename the tab while they work.

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
their normal stdout without breaking the signal. When a hook runner starts its
commands in a new session without a controlling terminal, as Claude Code does,
the helper instead writes to the pseudo-terminal still open on one of its
ancestor processes, which is the agent's own WezTerm pane. Outside WezTerm, or
when no terminal can be found, it exits silently.

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
  `~/.claude/settings.json`. It marks submitted prompts and completed tool
  calls as running, permission requests and questions to the user as needing
  attention, normal stops as completed, and API-error stops as failed. The
  attention state is published from both the `PermissionRequest` hook and the
  `Notification` hook (`permission_prompt`, `agent_needs_input`, and
  elicitation dialogs), so it also covers `AskUserQuestion` prompts. Hook
  entries for events already present in `settings.json` must be appended to
  that event's list rather than replacing it.
- Codex: merge `integrations/codex-hooks.toml` into
  `~/.codex/config.toml`. Current hooks cover running, permission requests, and
  successful turn completion. The integration disables Codex's built-in
  terminal-title updates and TUI alerts, preserving the working-directory title
  rendered by WezTerm and using `bin/codex-wezterm-notify` exclusively for
  completed turns. Its
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
  The host worker requests a two-second expiration and explicitly closes the
  notification after two seconds, even when the desktop ignores its requested
  expiration timeout.
  Dismissing it does not change focus or acknowledge the pink tab indicator.
  The `codex-wezterm-notify` command must be available inside the environment
  where Codex runs; containerized Codex images should install their own copy.
  Use `wezterm-agent-state failed` manually or from an additional local hook
  when a surrounding workflow detects failure.
- opencode: `install.sh` places `integrations/opencode-agent-state.js` in
  `~/.config/opencode/plugins/`, which opencode auto-loads at startup. It uses
  documented session, permission, and tool events to cover all four states.
  opencode reads its plugin directory only when it starts, so restart opencode
  after installing or updating the plugin; the state is published to the
  WezTerm pane opencode itself runs in. Without the installer, copy the file to
  `~/.config/opencode/plugins/` manually.

Run notification regression tests without sending desktop alerts:

```bash
python3 -B -m unittest discover -s tests -v
```

The tests cover the hidden title completion followed by the real task completion
on both delivery routes, ordinary title/JSON tasks, and terminal request clearing.
They also run `wezterm-agent-state` without a controlling terminal, as Claude
Code hooks do, and check that the state reaches the ancestor's terminal.
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
  { module = rendering_backend, enabled = true },
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
