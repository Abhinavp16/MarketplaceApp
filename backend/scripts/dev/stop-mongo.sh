#!/usr/bin/env bash
# Stops the demo mongod started by start-mongo.sh (data is kept in ./.data).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PID_FILE="$ROOT/.data/mongod.pid"
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  PID="$(cat "$PID_FILE")"
  kill "$PID"
  for _ in $(seq 1 30); do kill -0 "$PID" 2>/dev/null || break; sleep 0.5; done
  echo "Demo mongod stopped."
else
  echo "Demo mongod is not running."
fi
