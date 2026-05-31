#!/bin/sh
set -eu

repo_dir="$(cd "$(dirname "$0")" && pwd)"
backup_dir="$HOME/.config-backups/dotfiles-2-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$HOME/.config"

for dir in driftwm waybar fuzzel swaync alacritty; do
    if [ -e "$HOME/.config/$dir" ]; then
        mkdir -p "$backup_dir"
        cp -a "$HOME/.config/$dir" "$backup_dir/$dir"
    fi
done

rsync -a "$repo_dir/config/" "$HOME/.config/"

chmod +x "$HOME/.config/driftwm/scripts/"*.sh
chmod +x "$HOME/.config/driftwm/widgets/launch.sh"

if command -v driftwm >/dev/null 2>&1; then
    driftwm --check-config
fi

printf 'Installed dotfiles-2 configs.\n'
printf 'Backup dir: %s\n' "$backup_dir"

