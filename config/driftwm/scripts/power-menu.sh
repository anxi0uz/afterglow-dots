#!/bin/sh
set -eu

RICE="${XDG_CONFIG_HOME:-$HOME/.config}/driftwm"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "power" "$1" >/dev/null 2>&1 || true
    fi
}

if ! command -v fuzzel >/dev/null 2>&1; then
    notify "fuzzel not found"
    exit 1
fi

choice="$(
    printf '%s\n' \
        lock \
        suspend \
        logout \
        reboot \
        poweroff \
        cancel |
        fuzzel --dmenu --prompt "power> " --config "$RICE/fuzzel/fuzzel.ini"
)"

case "$choice" in
    lock)
        "$RICE/scripts/lock.sh"
        ;;
    suspend)
        systemctl suspend
        ;;
    logout)
        pkill -x driftwm
        ;;
    reboot)
        systemctl reboot
        ;;
    poweroff)
        systemctl poweroff
        ;;
    cancel|"")
        exit 0
        ;;
    *)
        exit 2
        ;;
esac
