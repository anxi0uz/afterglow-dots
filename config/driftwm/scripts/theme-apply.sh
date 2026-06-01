#!/bin/sh
# Apply rice theme to driftwm + waybar configs.
# Usage: theme-apply.sh light|dark [--no-restart]
#
# driftwm picks up config.toml changes via mtime poll (~500ms).
# waybar is killed and relaunched in autostart order — unless --no-restart.

set -eu

mode="${1:-}"
no_restart="${2:-}"

case "$mode" in
    light|dark) ;;
    *) echo "usage: $0 light|dark [--no-restart]" >&2; exit 2 ;;
esac

RICE="$HOME/.config/driftwm"

if [ "$mode" = "light" ]; then
    BG="#FDF6E3"
    FG="#5C6A72"
    SHADER="pink_cloud.glsl"
else
    BG="#272E33"
    FG="#D3C6AA"
    SHADER="dark_sea.glsl"
fi

# driftwm: decorations.bg_color, decorations.fg_color, background.path
# (output.outline.color stays light — same in both modes by design)
sed -i \
    -e "s|^bg_color = \".*\"|bg_color = \"$BG\"|" \
    -e "s|^fg_color = \".*\"|fg_color = \"$FG\"|" \
    -e "s|^path = \".*/wallpapers/[^\"]*\\.glsl\"|path = \"$RICE/wallpapers/static/$SHADER\"|" \
    "$RICE/config.toml"

# driftwm alacritty: swap import to colors-{light,dark}.toml.
sed -i "s|colors-[a-z]*\\.toml|colors-${mode}.toml|" "$RICE/alacritty/alacritty.toml"

# waybar CSS: only `background:` inside window#waybar and tooltip blocks.
# Leaves button.active background (accent) and tooltip color (fg, mode-constant
# per current spec) untouched.
for f in "$HOME/.config/waybar/bottom.css"; do
    awk -v bg="$BG" '
        /^window#waybar \{/ { in_block = 1 }
        /^tooltip \{/       { in_block = 1 }
        /^\}/               { in_block = 0 }
        in_block && /background:/ { sub(/#[A-Fa-f0-9]+/, bg) }
        { print }
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

if [ "$no_restart" = "--no-restart" ]; then
    exit 0
fi

# Restart the screen-anchored bottom bar.
pkill -x waybar 2>/dev/null || true
sleep 0.3
waybar -c "$HOME/.config/waybar/bottom.jsonc" -s "$HOME/.config/waybar/bottom.css" &

# swayosd-server snapshots the GTK theme at startup; restart for OSD popups
# (volume, brightness) to render in the new palette.
if command -v swayosd-server >/dev/null 2>&1; then
    pkill -x swayosd-server 2>/dev/null || true
    sleep 0.2
    swayosd-server --top-margin 0.95 &
fi
