#!/usr/bin/env python3
import ctypes
import json
import os
import struct
import time
from pathlib import Path

IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE_SELF = 0x00000400
IN_MOVE_SELF = 0x00000800

EVENT_STRUCT = "iIII"
EVENT_SIZE = struct.calcsize(EVENT_STRUCT)
WATCH_MASK = IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE | IN_DELETE_SELF | IN_MOVE_SELF


def state_dir() -> Path:
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return Path(runtime) / "driftwm"


def state_path() -> Path:
    return state_dir() / "state"


def read_state() -> dict[str, str]:
    result: dict[str, str] = {}
    try:
        for line in state_path().read_text().splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                result[key.strip()] = value.strip()
    except OSError:
        pass
    return result


def emit() -> None:
    state = read_state()
    x = state.get("x", "?")
    y = state.get("y", "?")
    zoom = state.get("zoom", "?")
    print(
        json.dumps(
            {
                "text": f"[x{x} y{y}]",
                "tooltip": f"zoom: {zoom}",
            },
            separators=(",", ":"),
        ),
        flush=True,
    )


def inotify_fd() -> int:
    libc = ctypes.CDLL("libc.so.6", use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_init1.restype = ctypes.c_int
    fd = libc.inotify_init1(getattr(os, "O_CLOEXEC", 0))
    if fd < 0:
        errno = ctypes.get_errno()
        raise OSError(errno, os.strerror(errno))
    return fd


def add_watch(fd: int) -> int:
    libc = ctypes.CDLL("libc.so.6", use_errno=True)
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    libc.inotify_add_watch.restype = ctypes.c_int
    wd = libc.inotify_add_watch(fd, os.fsencode(state_dir()), WATCH_MASK)
    if wd < 0:
        errno = ctypes.get_errno()
        raise OSError(errno, os.strerror(errno))
    return wd


def wait_for_updates(fd: int) -> None:
    while True:
        data = os.read(fd, 4096)
        offset = 0
        changed = False
        watch_lost = False

        while offset + EVENT_SIZE <= len(data):
            _wd, mask, _cookie, name_len = struct.unpack_from(EVENT_STRUCT, data, offset)
            offset += EVENT_SIZE
            name = data[offset : offset + name_len].rstrip(b"\0").decode(errors="replace")
            offset += name_len

            if name == "state" or mask & (IN_DELETE_SELF | IN_MOVE_SELF):
                changed = True
            if mask & (IN_DELETE_SELF | IN_MOVE_SELF):
                watch_lost = True

        if changed:
            emit()
        if watch_lost:
            return


def main() -> int:
    emit()
    fd = inotify_fd()
    while True:
        try:
            add_watch(fd)
        except OSError:
            time.sleep(0.25)
            continue
        wait_for_updates(fd)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        raise SystemExit(0)
    except KeyboardInterrupt:
        raise SystemExit(0)
