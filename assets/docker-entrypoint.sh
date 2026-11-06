#!/bin/sh
set -eu

umask 027
LOG_DIR="${LOG_DIR:-/app/logs}"
mkdir -p "$LOG_DIR"
exec "$@" >> "$LOG_DIR/app.log" 2>&1
