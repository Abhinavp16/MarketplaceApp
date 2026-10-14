#!/usr/bin/env bash
# Rebuild a client's images from the current source and restart its services one by one.
# Volumes (uploads, certificates) are kept. Your MongoDB is never touched.
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || { echo "Usage: ./update-client.sh <slug> [--no-cache] [--pull]"; exit 1; }
SLUG="$1"; shift
NO_CACHE=""; PULL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-cache) NO_CACHE="--no-cache" ;;
    --pull) PULL="--pull" ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done
require_client "$SLUG"
docker_ready
assert_project_owned "$SLUG"

LOG="$(client_dir "$SLUG")/update.log"
: >"$LOG"
info "Rebuilding images for $SLUG (log: $LOG)"
for svc in backend admin site; do
  info "  building $svc ..."
  # shellcheck disable=SC2086
  if ! dc "$SLUG" build $NO_CACHE $PULL "$svc" >>"$LOG" 2>&1; then
    tail -n 25 "$LOG" >&2
    die "Build of '$svc' failed; the running services were not touched"
  fi
done

for svc in backend admin site proxy; do
  info "Restarting $svc"
  dc "$SLUG" up -d --no-deps "$svc" >>"$LOG" 2>&1 || { tail -n 25 "$LOG" >&2; die "Could not restart $svc"; }
  if [ "$svc" != "proxy" ]; then wait_healthy "$SLUG" "$svc" 240; fi
done
assert_project_owned "$SLUG"
wait_http "http://127.0.0.1:$(cenv "$SLUG" BACKEND_PORT)/health" "" 60 || die "API did not answer after the update"
info "Updated $SLUG. Data volumes were kept."
dc "$SLUG" ps
