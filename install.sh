#!/bin/sh

# Install a self-contained copy of the configuration outside this checkout.
set -eu

usage() {
  cat <<'EOF'
usage: ./install.sh [--config-dir DIR] [--bin-dir DIR] [--opencode-plugins-dir DIR]

Copies the WezTerm configuration to ~/.config/wezterm (or $XDG_CONFIG_HOME/wezterm)
and its helper commands to ~/.local/bin by default, and the opencode agent-state
plugin to ~/.config/opencode/plugins (or $XDG_CONFIG_HOME/opencode/plugins).
On Linux, also installs a user desktop launcher under $XDG_DATA_HOME/applications
(or ~/.local/share/applications) that starts a fresh GUI with the installed config.
EOF
}

if [ -z "${HOME:-}" ]; then
  echo "install.sh: HOME must be set" >&2
  exit 1
fi

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
default_config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/wezterm
config_dir=$default_config_dir
bin_dir=$HOME/.local/bin
opencode_plugins_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/opencode/plugins

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      config_dir=$2
      shift 2
      ;;
    --bin-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      bin_dir=$2
      shift 2
      ;;
    --opencode-plugins-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      opencode_plugins_dir=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "install.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

timestamp=$(date +%Y%m%d-%H%M%S)

backup_existing() {
  path=$1
  if [ -e "$path" ] || [ -L "$path" ]; then
    backup="$path.backup-$timestamp"
    suffix=0
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      suffix=$((suffix + 1))
      backup="$path.backup-$timestamp-$suffix"
    done
    mv -- "$path" "$backup"
    echo "Backed up $path to $backup"
  fi
}

config_parent=$(dirname -- "$config_dir")
mkdir -p -- "$config_parent" "$bin_dir"
staging_dir=$(mktemp -d "$config_parent/.wezterm-install.XXXXXX")
trap 'rm -rf -- "$staging_dir"' EXIT HUP INT TERM

mkdir -p -- "$staging_dir/features" "$staging_dir/bin"
cp -- "$source_dir/wezterm.lua" "$staging_dir/wezterm.lua"
cp -- "$source_dir"/features/*.lua "$staging_dir/features/"
cp -- "$source_dir/bin/codex-wezterm-notify" "$staging_dir/bin/"
chmod 755 "$staging_dir/bin/codex-wezterm-notify"

backup_existing "$config_dir"
mv -- "$staging_dir" "$config_dir"

for command in wezterm-agent-state wezterm-tab-task codex-wezterm-notify; do
  destination=$bin_dir/$command
  backup_existing "$destination"
  cp -- "$source_dir/bin/$command" "$destination"
  chmod 755 "$destination"
done

mkdir -p -- "$opencode_plugins_dir"
opencode_plugin=$opencode_plugins_dir/opencode-agent-state.js
backup_existing "$opencode_plugin"
cp -- "$source_dir/integrations/opencode-agent-state.js" "$opencode_plugin"
echo "Installed opencode plugin in $opencode_plugin"

# ~/.wezterm.lua takes precedence on some WezTerm installations.
if [ "$config_dir" = "$default_config_dir" ]; then
  backup_existing "$HOME/.wezterm.lua"
fi

if [ "$(uname -s)" = Linux ]; then
  applications_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}/applications
  desktop_file=$applications_dir/org.wezfurlong.wezterm.desktop
  installed_config_dir=$(CDPATH='' cd -- "$config_dir" && pwd)
  # Desktop Exec values have both string escaping and argument quoting, plus
  # percent field codes. Never interpret the config path as shell commands.
  desktop_config=$(printf '%s' "$installed_config_dir/wezterm.lua" |
    sed -e 's/\\/\\\\\\\\/g' -e 's/["`$]/\\\\&/g' -e 's/%/%%/g')
  mkdir -p -- "$applications_dir"
  backup_existing "$desktop_file"
  cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=WezTerm
Comment=Wez's Terminal Emulator
Keywords=shell;prompt;command;commandline;cmd;
Icon=org.wezfurlong.wezterm
StartupWMClass=org.wezfurlong.wezterm
TryExec=wezterm
Exec=wezterm --config-file "$desktop_config" start --always-new-process --cwd .
Type=Application
Categories=System;TerminalEmulator;Utility;
Terminal=false
EOF
  echo "Installed desktop launcher in $desktop_file"
fi

echo "Installed WezTerm configuration in $config_dir"
echo "Installed helper commands in $bin_dir"
echo "Installed opencode plugin in $opencode_plugins_dir/opencode-agent-state.js"

case ":${PATH:-}:" in
  *:"$bin_dir":*) ;;
  *) echo "Add $bin_dir to PATH to use the helper commands." ;;
esac
