#!/bin/sh
set -eu

export ELECTRON_OZONE_PLATFORM_HINT=x11
exec discord --ozone-platform=x11 --ozone-platform-hint=x11 "$@"
