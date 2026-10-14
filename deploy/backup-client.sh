#!/usr/bin/env bash
# Backup one client: mongodump of its database + tar of its uploads volume -> backups/<slug>/<timestamp>/
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || { echo "Usage: ./backup-client.sh <slug> [--out <backups-dir>]"; exit 1; }
SLUG="$1"; shift
BASE="$DEPLOY_DIR/backups"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) [ $# -ge 2 ] || die "--out needs a directory"; BASE="$2"; shift ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done
require_client "$SLUG"
docker_ready
assert_project_owned "$SLUG"
require_running "$SLUG"

DB="$(cenv "$SLUG" MONGO_DB_NAME)"
DEST="$BASE/$SLUG/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BASE/$SLUG"
( umask 077; mkdir "$DEST" ) || die "Backup folder already exists or cannot be created: $DEST"

info "Backing up $SLUG (database $DB) to $DEST"
dump_mongo "$SLUG" "$DEST/mongodb-$DB.archive.gz"
tar_uploads "$SLUG" "$DEST/uploads.tar.gz"
( cd "$DEST" && for f in mongodb-"$DB".archive.gz uploads.tar.gz; do printf '%s  %s\n' "$(sha256_of "$f")" "$f"; done >SHA256SUMS )
cat >"$DEST/RESTORE.txt" <<EOF
Backup of client '$SLUG' (database $DB), $(date -u +%Y-%m-%dT%H:%M:%SZ)

Restore the database into your MongoDB (the URL is in clients/$SLUG/.env as MONGODB_URI):
  mongorestore --uri "<your MongoDB URL>" --archive=mongodb-$DB.archive.gz --gzip --drop --nsInclude '$DB.*'
Restore the uploads into the running client (from the deploy/ folder):
  docker compose -p demomart-$SLUG --env-file clients/$SLUG/.env exec -T backend \\
    tar -C /data -xzf - < uploads.tar.gz
The .env file (secrets) is NOT part of this backup; keep clients/$SLUG/.env somewhere safe.
EOF
info "Done:"
ls -l "$DEST"
