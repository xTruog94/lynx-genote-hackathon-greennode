#!/bin/sh
# API and Celery share this container so a single AgentBase runtime can serve
# HTTP and studio jobs. AgentBase requires port 8080.
set -u

cd /app
export PYTHONPATH="/app:/app/doc-ocr${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONUNBUFFERED=1
export TIKTOKEN_CACHE_DIR="${TIKTOKEN_CACHE_DIR:-/app/data/tiktoken}"

WORKER_PID=""
GUNICORN_PID=""

shutdown() {
    if [ -n "$GUNICORN_PID" ]; then
        kill -TERM "$GUNICORN_PID" 2>/dev/null || true
    fi
    if [ -n "$WORKER_PID" ]; then
        kill -TERM "$WORKER_PID" 2>/dev/null || true
    fi
    wait || true
}
trap shutdown TERM INT

if [ "${RUN_CELERY_WORKER:-1}" != "0" ]; then
    celery -A backend.celery_app.celery_app worker \
        --loglevel="${CELERY_LOG_LEVEL:-INFO}" \
        --queues="${CELERY_DEFAULT_QUEUE:-genote_studio}" \
        --concurrency="${CELERY_CONCURRENCY:-1}" \
        --hostname="genote-studio-worker@%h" &
    WORKER_PID=$!
fi

gunicorn backend.main:app \
    -k uvicorn.workers.UvicornWorker \
    --bind "0.0.0.0:${PORT:-8080}" \
    --workers "${GUNICORN_WORKERS:-2}" \
    --timeout "${GUNICORN_TIMEOUT:-600}" \
    --graceful-timeout 30 \
    --keep-alive 5 &
GUNICORN_PID=$!

wait "$GUNICORN_PID"
STATUS=$?
shutdown
exit "$STATUS"
