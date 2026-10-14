#!/usr/bin/env bash
# Stop one client. Uploads are kept unless --destroy-data (which asks twice).
# The client's MongoDB is external and is NEVER touched by this script.
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || { echo "Usage: ./stop-client.sh <slug> [--destroy-data [--remove-config]]   (never touches the database)"; exit 1; }
SLUG="$1"; shift
DESTROY=0; REMOVE_CONFIG=0
while [ $# -gt 0 ]; do
  case "$1" in
    --destroy-data) DESTROY=1 ;;
    --remove-config) REMOVE_CONFIG=1 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done
[ "$REMOVE_CONFIG" = 0 ] || [ "$DESTROY" = 1 ] || die "--remove-config only makes sense together with --destroy-data"
require_client "$SLUG"
docker_ready
assert_project_owned "$SLUG"
PROJECT="$(project_name "$SLUG")"

if [ "$DESTROY" = 0 ]; then
  dc "$SLUG" down --remove-orphans
  info "Stopped $PROJECT. The uploads volume is kept; your MongoDB was not touched. Start again with: ./update-client.sh $SLUG"
  exit 0
fi

echo "This permanently deletes the containers, the uploads/certificate volumes and the built images of client '$SLUG':"
echo "  containers: $(project_containers "$SLUG" | tr '\n' ' ')"
echo "  volumes:    $(project_volumes "$SLUG" | tr '\n' ' ')"
echo "The database ($(cenv "$SLUG" MONGO_DB_NAME) at $(mask_uri "$(cenv "$SLUG" MONGODB_URI)")) is NOT touched: drop it yourself on your MongoDB if you want it gone."
echo "Tip: ./backup-client.sh $SLUG or ./export-client.sh $SLUG first (uploads are lost otherwise)."
printf 'Type the client slug (%s) to continue: ' "$SLUG"
A="$(read_line)"; echo
[ "$A" = "$SLUG" ] || die "Not confirmed; nothing was deleted"
printf 'Last chance. Type  DELETE %s  to destroy the uploads and containers: ' "$SLUG"
B="$(read_line)"; echo
[ "$B" = "DELETE $SLUG" ] || die "Not confirmed; nothing was deleted"

assert_project_owned "$SLUG"
dc "$SLUG" down --volumes --remove-orphans --rmi local
echo "Destroyed containers, volumes and images of $PROJECT. The database was not touched."
if [ "$REMOVE_CONFIG" = 1 ]; then
  rm -rf -- "$(client_dir "$SLUG")"
  echo "Removed clients/$SLUG."
else
  echo "clients/$SLUG was kept (it holds the secrets/config). Remove it with --remove-config to reuse the slug."
fi
