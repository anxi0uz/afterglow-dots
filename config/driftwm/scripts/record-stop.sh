#!/bin/sh
set -eu

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/driftwm"
pid_file="$runtime_dir/gpu-screen-recorder.pid"

stop_pid() {
    pid="$1"
    [ -n "$pid" ] || return 1

    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    case "$args" in
        *gpu-screen-recorder*)
            kill -INT "$pid" 2>/dev/null || return 1
            return 0
            ;;
    esac

    return 1
}

if [ -s "$pid_file" ]; then
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if stop_pid "$pid"; then
        rm -f "$pid_file"
        notify-send "Recording stopped" "Saved to ~/Videos" 2>/dev/null || true
        exit 0
    fi
    rm -f "$pid_file"
fi

pids="$(pgrep -u "$(id -u)" -f '(^|/)gpu-screen-recorder( |$)' 2>/dev/null || true)"
if [ -n "$pids" ]; then
    for pid in $pids; do
        kill -INT "$pid" 2>/dev/null || true
    done
    notify-send "Recording stopped" "Saved to ~/Videos" 2>/dev/null || true
    exit 0
fi

notify-send "Recording" "No active recording" 2>/dev/null || true
