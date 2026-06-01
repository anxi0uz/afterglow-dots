#!/bin/sh
# Minimal blur-lock: per-output screenshot, darken/blur, no swaylock circle.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

font="/usr/share/fonts/TTF/FantasqueSansMNerdFontMono-Regular.ttf"
stamp="$(date '+%a %d %b  %H.%M')"
blur_filter="boxblur=12:2,eq=brightness=-0.10:saturation=0.68"
label_filter="drawbox=x=(iw-360)/2:y=(ih-52)/2:w=360:h=52:color=050605cc:t=fill,drawbox=x=(iw-360)/2:y=(ih-52)/2:w=360:h=52:color=252520:t=1,drawtext=fontfile=${font}:text='locked  ${stamp}':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=15:fontcolor=d8d2c3"

render_lock_image() {
    src="$1"
    dst="$2"

    if ! ffmpeg -y -i "$src" -vf "${blur_filter},${label_filter}" "$dst" 2>/dev/null; then
        ffmpeg -y -i "$src" -vf "$blur_filter" "$dst" 2>/dev/null
    fi
}

args=""
for out in $(wlr-randr 2>/dev/null | awk '/^[^ \t]/ {print $1}'); do
    grim -l 0 -o "$out" "$tmpdir/$out.png" || continue
    render_lock_image "$tmpdir/$out.png" "$tmpdir/$out-lock.png"
    args="$args -i $out:$tmpdir/$out-lock.png"
done

# Fallback to whole-canvas grab if per-output enumeration failed
if [ -z "$args" ]; then
    grim -l 0 "$tmpdir/all.png"
    render_lock_image "$tmpdir/all.png" "$tmpdir/all-lock.png"
    args="-i $tmpdir/all-lock.png"
fi

swaylock -f $args \
    --scaling fill \
    --no-unlock-indicator \
    --ignore-empty-password
