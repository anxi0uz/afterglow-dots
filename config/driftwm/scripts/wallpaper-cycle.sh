#!/bin/sh
set -eu

RICE="${XDG_CONFIG_HOME:-$HOME/.config}/driftwm"
CONFIG="$RICE/config.toml"
WALLPAPER_DIR="$RICE/wallpapers"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "driftwm wallpaper" "$1" >/dev/null 2>&1 || true
    fi
}

if [ ! -f "$CONFIG" ]; then
    notify "config.toml not found"
    exit 1
fi

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify "wallpapers directory not found"
    exit 1
fi

wallpapers="$(find "$WALLPAPER_DIR" -type f -name '*.glsl' | sort)"
if [ -z "$wallpapers" ]; then
    notify "no .glsl wallpapers found"
    exit 1
fi

current="$(
    awk '
        /^\[background\]/ { in_background = 1; next }
        in_background && /^\[/ { in_background = 0 }
        in_background && /^[[:space:]]*path[[:space:]]*=/ {
            line = $0
            sub(/^[^"]*"/, "", line)
            sub(/".*$/, "", line)
            print line
            exit
        }
    ' "$CONFIG"
)"

mode="${1:-next}"

case "$mode" in
    next|"")
        first=""
        next=""
        use_next=0

        while IFS= read -r wallpaper; do
            [ -n "$first" ] || first="$wallpaper"

            if [ "$use_next" -eq 1 ]; then
                next="$wallpaper"
                break
            fi

            if [ "$wallpaper" = "$current" ]; then
                use_next=1
            fi
        done <<EOF
$wallpapers
EOF

        [ -n "$next" ] || next="$first"
        ;;
    random)
        next="$(printf '%s\n' "$wallpapers" | awk 'BEGIN { srand() } { item[++n] = $0 } END { if (n > 0) print item[int(rand() * n) + 1] }')"
        ;;
    *)
        echo "usage: $0 [next|random]" >&2
        exit 2
        ;;
esac

tmp="$(mktemp "$CONFIG.XXXXXX")"
if awk -v target="$next" '
    /^\[background\]/ { in_background = 1; print; next }
    in_background && /^\[/ { in_background = 0 }
    in_background && /^[[:space:]]*path[[:space:]]*=/ {
        print "path = \"" target "\""
        replaced = 1
        next
    }
    { print }
    END { if (!replaced) exit 3 }
' "$CONFIG" > "$tmp"; then
    chmod --reference="$CONFIG" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
    mv "$tmp" "$CONFIG"
else
    rm -f "$tmp"
    notify "failed to update config.toml"
    exit 1
fi

label="${next#$WALLPAPER_DIR/}"
notify "$label"
