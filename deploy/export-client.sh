#!/usr/bin/env bash
# Hand-over export of one client: database dump + uploads + readable CSV/XLSX + manifest + README.
# Writes exports/<slug>-<YYYYmmdd-HHMM>/ (or <--out dir>/<slug>-<YYYYmmdd-HHMM>/).
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || { echo "Usage: ./export-client.sh <slug> [--out <dir>]"; exit 1; }
SLUG="$1"; shift
BASE="$DEPLOY_DIR/exports"
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
NAME="$(cenv "$SLUG" CLIENT_NAME)"
mkdir -p "$BASE"
OUT="$BASE/$SLUG-$(stamp)"
( umask 077; mkdir "$OUT" ) || die "Export folder already exists or cannot be created: $OUT (wait a minute or use --out)"
mkdir "$OUT/data"
EXPORTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

info "Exporting $SLUG (database $DB) to $OUT"
info "  1/3 database dump"
dump_mongo "$SLUG" "$OUT/mongodb-$DB.archive.gz"
info "  2/3 uploads volume"
tar_uploads "$SLUG" "$OUT/uploads.tar.gz"
info "  3/3 readable CSV + XLSX"
# The export script runs in the backend container (so it reaches MongoDB the same way the API does)
# and streams its files back as a tar; nothing is bind-mounted and no host user ids are involved.
dc "$SLUG" exec -T backend sh -c "rm -rf /tmp/client-export && node scripts/export-client-data.js --out /tmp/client-export --slug '$SLUG' --db '$DB' >&2 && tar -C /tmp/client-export -cf - . && rm -rf /tmp/client-export" \
  | tar -xf - -C "$OUT/data" || die "The data export failed"
[ -s "$OUT/data/counts.json" ] || die "The data export produced no counts.json"

# ---- secrets check: nothing sensitive may appear in the readable files
if grep -rIlE 'passwordHash|refreshToken|fcmToken|JWT_SECRET|BEGIN (RSA )?PRIVATE KEY' "$OUT/data" >/dev/null 2>&1; then
  die "Secret-looking text was found in the export; removing it is safer than shipping it. Inspect: $OUT/data"
fi

# ---- README.txt
cat >"$OUT/README.txt" <<EOF
Data export for $NAME ($SLUG)
Exported at: $EXPORTED_AT (UTC)     Database: $DB

Contents
  mongodb-$DB.archive.gz   full database dump (mongodump --archive --gzip)
  uploads.tar.gz           uploaded images and private media (the /data volume of the API)
  data/export.xlsx         every dataset as one sheet each
  data/*.csv               the same data as UTF-8 CSV (products, products_catalog_import, brands, categories, customers,
                           orders, order_items, order_status_history, payments, negotiations,
                           negotiation_history, price_history, stock_logs)
  data/counts.json         number of rows per dataset
  manifest.json            counts, file sizes and SHA-256 checksum of every file

No passwords, tokens or other secrets are included in the CSV/XLSX files. The database dump
does contain password hashes and tokens (it is a full copy): store it like a secret.

Verify a file:      shasum -a 256 <file>   (compare with its "sha256" entry in manifest.json)

Restore the database into any MongoDB (replica set) with mongorestore --uri; the URL is your own:
  mongorestore --uri "<your MongoDB URL>" --archive=mongodb-$DB.archive.gz --gzip --drop --nsInclude '$DB.*'
(no mongorestore installed? run it from a throw-away container:
  docker run --rm -i -e MONGODB_URI mongo:7 sh -c 'mongorestore --uri="\$MONGODB_URI" --archive --gzip --drop --nsInclude "$DB.*"' < mongodb-$DB.archive.gz )
Restore the uploads into a running client (from the deploy/ folder):
  docker compose -p demomart-$SLUG --env-file clients/$SLUG/.env exec -T backend \\
    tar -C /data -xzf - < uploads.tar.gz

Re-import the product catalog elsewhere
  data/products_catalog_import.csv (also the "Catalog import format" sheet of data/export.xlsx) has
  the same columns as the platform's catalog import template (backend: docs/catalog-import-sample.csv).
  Load it into any stack of the platform (a re-import of unchanged rows reports "no changes"):
    npm run catalog:import -- products_catalog_import.csv --dry-run
    npm run catalog:import -- products_catalog_import.csv --create-missing
  Inside a deployed stack see deploy/README.md, "Importing a catalog".
  data/products.csv is the fuller, read-only product listing (brand, category, prices, stock, pack,
  coming-soon fields, images).
EOF

# ---- manifest.json (counts + checksums of every file in this folder)
{
  printf '{\n'
  printf '  "client": "%s",\n' "$SLUG"
  printf '  "clientName": "%s",\n' "$NAME"
  printf '  "database": "%s",\n' "$DB"
  printf '  "exportedAt": "%s",\n' "$EXPORTED_AT"
  printf '  "counts": %s,\n' "$(sed '1!s/^/  /' "$OUT/data/counts.json")"
  printf '  "files": [\n'
  first=1
  ( cd "$OUT" && find . -type f ! -name manifest.json | sed 's#^\./##' | LC_ALL=C sort ) | while IFS= read -r rel; do
    [ "$first" = 1 ] || printf ',\n'
    first=0
    printf '    { "bytes": %s, "sha256": "%s", "path": "%s" }' "$(file_bytes "$OUT/$rel")" "$(sha256_of "$OUT/$rel")" "$rel"
  done
  printf '\n  ]\n}\n'
} >"$OUT/manifest.json"
chmod 600 "$OUT"/*.gz "$OUT/manifest.json" 2>/dev/null || true

info "Export complete: $OUT"
ls -l "$OUT" "$OUT/data"
