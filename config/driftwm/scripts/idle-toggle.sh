#!/bin/sh
set -eu

LOCK_SH="${XDG_CONFIG_HOME:-$HOME/.config}/driftwm/scripts/lock.sh"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "driftwm idle" "$1" >/dev/null 2>&1 || true
    fi
}

is_running() {
    pgrep -x swayidle >/dev/null 2>&1
}

start_idle() {
    if is_running; then
        notify "auto lock already enabled"
        return 0
    fi

    if ! command -v swayidle >/dev/null 2>&1; then
        notify "swayidle not found"
        return 1
    fi

    swayidle -w \
        timeout 300 'brightnessctl -s set 10%' \
        resume 'brightnessctl -r' \
        timeout 330 "$LOCK_SH" \
        timeout 600 'systemctl suspend' \
        before-sleep "$LOCK_SH" \
        >/dev/null 2>&1 &

    notify "auto lock enabled"
}

stop_idle() {
    if is_running; then
        pkill -x swayidle >/dev/null 2>&1 || true
        brightnessctl -r >/dev/null 2>&1 || true
        notify "caffeine on: auto lock disabled"
    else
        notify "caffeine already on"
    fi
}

case "${1:-toggle}" in
    toggle)
        if is_running; then
            stop_idle
        else
            start_idle
        fi
        ;;
    start|enable|off)
        start_idle
        ;;
    stop|disable|on)
        stop_idle
        ;;
    status)
        if is_running; then
            echo "auto-lock"
        else
            echo "caffeine"
        fi
        ;;
    *)
        echo "usage: $0 [toggle|start|stop|status]" >&2
        exit 2
        ;;
esac
