#!/usr/bin/env bash
# Starts a LOCAL, isolated mongod (single-node replica set "rs0") for the demo.
#
#   npm run demo:mongo            # start (idempotent) + initiate replica set
#   npm run demo:mongo:stop       # stop it again
#
# Data lives in ./.data/db (gitignored). The port defaults to 27018 so it can
# never collide with (or touch) another MongoDB you may already run on 27017.
# Override with DEMO_MONGO_PORT / MONGOD_BIN. Binds to 127.0.0.1 only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${DEMO_MONGO_PORT:-27018}"
MONGOD="${MONGOD_BIN:-/opt/homebrew/bin/mongod}"
if [ ! -x "$MONGOD" ]; then MONGOD="$(command -v mongod || true)"; fi
if [ -z "$MONGOD" ]; then echo "mongod not found. Install MongoDB Community Edition (brew install mongodb-community)." >&2; exit 1; fi

DATA_DIR="$ROOT/.data"
DB_PATH="$DATA_DIR/db"
LOG_FILE="$DATA_DIR/mongod.log"
PID_FILE="$DATA_DIR/mongod.pid"
mkdir -p "$DB_PATH"

is_running() {
  [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

if is_running; then
  echo "Demo mongod already running (pid $(cat "$PID_FILE"), port $PORT)."
else
  if (echo > "/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
    echo "Port $PORT is already in use by another process. Set DEMO_MONGO_PORT to a free port." >&2
    exit 1
  fi
  echo "Starting demo mongod on 127.0.0.1:$PORT (dbpath $DB_PATH)..."
  # macOS mongod has no --fork, so run it detached with nohup.
  nohup "$MONGOD" --replSet rs0 --dbpath "$DB_PATH" --bind_ip 127.0.0.1 --port "$PORT" \
    --logpath "$LOG_FILE" --logappend >/dev/null 2>&1 &
  echo $! > "$PID_FILE"
  for _ in $(seq 1 60); do
    if (echo > "/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then break; fi
    if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "mongod exited unexpectedly; see $LOG_FILE" >&2; exit 1
    fi
    sleep 0.5
  done
fi

# Initiate the replica set (idempotent). Prefer mongosh, fall back to the driver.
if command -v mongosh >/dev/null 2>&1; then
  mongosh --quiet --port "$PORT" --eval "try { rs.status().ok } catch (e) { rs.initiate({_id:'rs0',members:[{_id:0,host:'127.0.0.1:$PORT'}]}) }" >/dev/null
else
  DEMO_MONGO_PORT="$PORT" node "$ROOT/scripts/dev/init-replset.js"
fi

echo "Replica set rs0 ready. Use:"
echo "  MONGODB_URI=mongodb://127.0.0.1:$PORT/tradehub_demo?replicaSet=rs0"
