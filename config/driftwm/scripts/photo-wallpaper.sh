#!/bin/sh
set -eu

RICE="${XDG_CONFIG_HOME:-$HOME/.config}/driftwm"
CONFIG="$RICE/config.toml"
DOTFILES_CONFIG="$HOME/dotfiles-2/config/driftwm/config.toml"
OUT_DIR="$RICE/wallpapers/generated"
DOTFILES_OUT_DIR="$HOME/dotfiles-2/config/driftwm/wallpapers/generated"
PHOTO_DIRS="${DRIFT_PHOTO_DIRS:-$HOME/Изображения:$HOME/Pictures}"
WIDTH="${DRIFT_WALLPAPER_WIDTH:-1920}"
HEIGHT="${DRIFT_WALLPAPER_HEIGHT:-1080}"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "driftwm photo wallpaper" "$1" >/dev/null 2>&1 || true
    fi
}

usage() {
    echo "usage: $0 [select|random|/path/to/image] [fill|fit]" >&2
}

list_images() {
    old_ifs="$IFS"
    IFS=:
    for dir in $PHOTO_DIRS; do
        [ -d "$dir" ] || continue
        find "$dir" -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            -print 2>/dev/null
    done
    IFS="$old_ifs"
}

select_image() {
    images="$1"
    menu="$(mktemp "${TMPDIR:-/tmp}/drift-photo-wallpaper.XXXXXX")"
    trap 'rm -f "$menu"' EXIT HUP INT TERM

    printf '%s\n' "$images" | awk '
        {
            name = $0
            sub(/^.*\//, "", name)
            count[name]++
            path[++n] = $0
            base[n] = name
        }
        END {
            for (i = 1; i <= n; i++) {
                label = base[i]
                if (count[base[i]] > 1) {
                    parent = path[i]
                    sub(/\/[^/]*$/, "", parent)
                    sub(/^.*\//, "", parent)
                    label = base[i] "  [" parent "]"
                }
                print label "\t" path[i]
            }
        }
    ' > "$menu"

    choice="$(cut -f1 "$menu" | fuzzel --dmenu --prompt "wallpaper> " \
        --config "$RICE/fuzzel/fuzzel.ini")"
    [ -n "$choice" ] || return 0

    awk -F '\t' -v choice="$choice" '$1 == choice { print $2; exit }' "$menu"
}

pick_image() {
    mode="$1"
    images="$(list_images | sort)"
    if [ -z "$images" ]; then
        notify "no images found in ~/Изображения or ~/Pictures"
        exit 1
    fi

    case "$mode" in
        select|"")
            if ! command -v fuzzel >/dev/null 2>&1; then
                notify "fuzzel not found"
                exit 1
            fi
            select_image "$images"
            ;;
        random)
            printf '%s\n' "$images" | awk 'BEGIN { srand() } { item[++n] = $0 } END { if (n > 0) print item[int(rand() * n) + 1] }'
            ;;
        /*)
            printf '%s\n' "$mode"
            ;;
        ~/*)
            printf '%s\n' "$HOME/${mode#~/}"
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

render_wallpaper() {
    src="$1"
    style="$2"
    out="$3"

    case "$style" in
        fill|"")
            vf="scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${WIDTH}:${HEIGHT},setsar=1"
            ffmpeg -y -hide_banner -loglevel error -i "$src" -vf "$vf" -frames:v 1 "$out"
            ;;
        fit)
            filter="[0:v]scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${WIDTH}:${HEIGHT},boxblur=24:2,eq=brightness=-0.04:saturation=0.75[bg];[0:v]scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1"
            ffmpeg -y -hide_banner -loglevel error -i "$src" -filter_complex "$filter" -frames:v 1 "$out"
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

update_config() {
    config="$1"
    target="$2"
    [ -f "$config" ] || return 0

    tmp="$(mktemp "$config.XXXXXX")"
    if awk -v target="$target" '
        /^\[background\]/ { in_background = 1; print; next }
        in_background && /^\[/ { in_background = 0 }
        in_background && /^[[:space:]]*type[[:space:]]*=/ {
            print "type = \"wallpaper\""
            type_replaced = 1
            next
        }
        in_background && /^[[:space:]]*path[[:space:]]*=/ {
            print "path = \"" target "\""
            path_replaced = 1
            next
        }
        { print }
        END { if (!type_replaced || !path_replaced) exit 3 }
    ' "$config" > "$tmp"; then
        chmod --reference="$config" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
        mv "$tmp" "$config"
    else
        rm -f "$tmp"
        notify "failed to update $(basename "$config")"
        exit 1
    fi
}

if ! command -v ffmpeg >/dev/null 2>&1; then
    notify "ffmpeg not found"
    exit 1
fi

pick_mode="${1:-select}"
style="${2:-fill}"
src="$(pick_image "$pick_mode")"

if [ -z "$src" ]; then
    exit 0
fi

if [ ! -f "$src" ]; then
    notify "image not found: $src"
    exit 1
fi

mkdir -p "$OUT_DIR" "$DOTFILES_OUT_DIR"
hash="$(printf '%s|%s|%sx%s' "$src" "$style" "$WIDTH" "$HEIGHT" | sha256sum | awk '{ print substr($1, 1, 16) }')"
out="$OUT_DIR/photo-${style}-${hash}.png"

render_wallpaper "$src" "$style" "$out"
cp "$out" "$DOTFILES_OUT_DIR/$(basename "$out")" 2>/dev/null || true
update_config "$CONFIG" "$out"
update_config "$DOTFILES_CONFIG" "$out"

notify "$(basename "$src") -> ${WIDTH}x${HEIGHT} ${style}"
