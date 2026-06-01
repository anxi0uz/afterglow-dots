#!/bin/sh
set -eu

if command -v zenity >/dev/null 2>&1; then
    zenity --calendar \
        --title "calendar" \
        --text "$(date '+%A, %d %B %Y')" \
        --date-format "%F" >/dev/null 2>&1 &
    exit 0
fi

if command -v cal >/dev/null 2>&1 && command -v notify-send >/dev/null 2>&1; then
    notify-send "calendar" "$(cal -m)" >/dev/null 2>&1 || true
fi
