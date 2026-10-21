#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"

cd "$APP_DIR"

export PYTHONPATH="$APP_DIR:${PYTHONPATH:-}"
export S3_INPUT_SUB_PREFIX="${S3_INPUT_SUB_PREFIX:-tvpl}"

if [ -x "$SCRIPT_DIR/genote-cron" ]; then
  exec "$SCRIPT_DIR/genote-cron"
fi
exec python3 "$SCRIPT_DIR/main.py"
