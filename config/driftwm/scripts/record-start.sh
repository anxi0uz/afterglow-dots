#!/bin/sh
set -eu

if ! command -v gpu-screen-recorder >/dev/null 2>&1; then
    notify-send "Recording" "gpu-screen-recorder is not installed" 2>/dev/null || true
    exit 1
fi

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/driftwm"
pid_file="$runtime_dir/gpu-screen-recorder.pid"
mkdir -p "$runtime_dir"

if [ -s "$pid_file" ]; then
    old_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        notify-send "Recording" "Already recording" 2>/dev/null || true
        exit 0
    fi
    rm -f "$pid_file"
fi

if pgrep -u "$(id -u)" -f '(^|/)gpu-screen-recorder( |$)' >/dev/null 2>&1; then
    notify-send "Recording" "Already recording" 2>/dev/null || true
    exit 0
fi

mkdir -p "$HOME/Videos"
out="$HOME/Videos/rec_$(date +%Y%m%d_%H%M%S).mp4"

set -- gpu-screen-recorder -w screen -f 60
if command -v pactl >/dev/null 2>&1; then
    sink="$(pactl get-default-sink 2>/dev/null || true)"
    if [ -n "$sink" ]; then
        set -- "$@" -a "$sink.monitor"
    fi
fi
set -- "$@" -o "$out"

notify-send "Recording started" "$out" 2>/dev/null || true

setsid "$@" >/tmp/gpu-screen-recorder.log 2>&1 &
printf '%s\n' "$!" > "$pid_file"
