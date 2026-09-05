#!/bin/sh

# Install a self-contained copy of the configuration outside this checkout.
set -eu

usage() {
  cat <<'EOF'
usage: ./install.sh [--config-dir DIR] [--bin-dir DIR]

Copies the WezTerm configuration to ~/.config/wezterm (or $XDG_CONFIG_HOME/wezterm)
and its helper commands to ~/.local/bin by default.
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

# ~/.wezterm.lua takes precedence on some WezTerm installations.
if [ "$config_dir" = "$default_config_dir" ]; then
  backup_existing "$HOME/.wezterm.lua"
fi

echo "Installed WezTerm configuration in $config_dir"
echo "Installed helper commands in $bin_dir"

case ":${PATH:-}:" in
  *:"$bin_dir":*) ;;
  *) echo "Add $bin_dir to PATH to use the helper commands." ;;
esac
