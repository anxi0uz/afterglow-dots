#!/bin/sh
set -eu

if ! command -v cliphist >/dev/null 2>&1 || ! command -v fuzzel >/dev/null 2>&1 || ! command -v wl-copy >/dev/null 2>&1; then
    notify-send "Clipboard" "cliphist, fuzzel or wl-copy is not installed" 2>/dev/null || true
    exit 1
fi

selection="$(
    cliphist list |
        fuzzel --config "$HOME/.config/driftwm/fuzzel/fuzzel.ini" --dmenu \
            --prompt="Clipboard: " \
            --width=90 \
            --no-run-if-empty
)"

[ -n "$selection" ] || exit 0
printf '%s\n' "$selection" | cliphist decode | wl-copy
