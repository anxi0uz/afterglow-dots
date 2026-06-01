#!/bin/sh
set -eu

mode="${1:-area}"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "screenshot" "$1" >/dev/null 2>&1 || true
    fi
}

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        notify "$1 not found"
        exit 1
    fi
}

copy_geometry() {
    geometry="$1"
    [ -n "$geometry" ] || exit 0
    grim -g "$geometry" - | wl-copy --type image/png
}

window_geometry() {
    python3 - <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def read_state() -> dict[str, str]:
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    path = Path(runtime) / "driftwm" / "state"
    result: dict[str, str] = {}
    for line in path.read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def output_size(output_name: str) -> tuple[int, int]:
    try:
        current_output = None
        output = subprocess.check_output(["wlr-randr"], text=True, stderr=subprocess.DEVNULL)
        for line in output.splitlines():
            if line and not line[0].isspace():
                current_output = line.split()[0]
                continue
            if current_output == output_name and "current" in line:
                match = re.search(r"(\d+)x(\d+)\s+px,", line)
                if match:
                    return int(match.group(1)), int(match.group(2))
    except Exception:
        pass

    try:
        import tomllib

        config = tomllib.loads(Path.home().joinpath(".config/driftwm/config.toml").read_text())
        for output in config.get("outputs", []):
            if output.get("name") == output_name:
                mode = output.get("mode", "")
                match = re.match(r"(\d+)x(\d+)@", mode)
                if match:
                    return int(match.group(1)), int(match.group(2))
    except Exception:
        pass

    return 1920, 1080


state = read_state()
windows = json.loads(state.get("windows", "[]"))
window = next(
    (w for w in windows if w.get("is_focused") and not w.get("is_widget")),
    None,
)
if window is None:
    window = next((w for w in windows if not w.get("is_widget")), None)
if window is None:
    raise SystemExit(1)

outputs: dict[str, dict[str, float]] = {}
for key, value in state.items():
    if not key.startswith("outputs."):
        continue
    rest = key.removeprefix("outputs.")
    name, _, field = rest.rpartition(".")
    if field not in {"camera_x", "camera_y", "zoom"}:
        continue
    outputs.setdefault(name, {})[field] = float(value)

output_name = next(iter(outputs), "")
output = outputs.get(output_name, {})
camera_x = output.get("camera_x", 0.0)
camera_y = output.get("camera_y", 0.0)
zoom = output.get("zoom", float(state.get("zoom", "1.0")))
output_w, output_h = output_size(output_name)

center_x, center_y = window["position"]
width, height = window["size"]

left = center_x - width / 2
top = -center_y - height / 2

x = round((left - camera_x) * zoom)
y = round((top - camera_y) * zoom)
w = round(width * zoom)
h = round(height * zoom)

x2 = min(output_w, x + w)
y2 = min(output_h, y + h)
x = max(0, x)
y = max(0, y)
w = x2 - x
h = y2 - y

if w <= 0 or h <= 0:
    raise SystemExit(1)

print(f"{x},{y} {w}x{h}")
PY
}

need grim
need wl-copy

case "$mode" in
    area)
        need slurp
        geometry="$(
            slurp \
                -b 05060566 \
                -c d8d2c3ff \
                -s d8d2c333 \
                -B 25252099 \
                -w 1
        )" || exit 0
        copy_geometry "$geometry"
        notify "area copied"
        ;;
    screen)
        grim - | wl-copy --type image/png
        notify "screen copied"
        ;;
    window)
        geometry="$(window_geometry)" || {
            notify "no focused window"
            exit 1
        }
        copy_geometry "$geometry"
        notify "window copied"
        ;;
    *)
        echo "usage: $0 [area|screen|window]" >&2
        exit 2
        ;;
esac
