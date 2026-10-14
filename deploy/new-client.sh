#!/usr/bin/env bash
# Create, build and start one isolated DemoMart client (own secrets, uploads, ports; its own MongoDB URL).
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
Usage: ./new-client.sh <slug> "<Client Name>" <domain> [options]

  slug      ^[a-z0-9-]{2,30}$ ; becomes the compose project demomart-<slug>
  domain    e.g. acme.example.com (real, automatic HTTPS) or acme.localhost (local test, plain HTTP)
            The stack serves  <domain> (site), admin.<domain> (admin panel), api.<domain> (API).

MongoDB (not part of this stack; you bring it, e.g. an Atlas cluster = a replica set):
  --mongo-uri "<url>"   mongodb:// or mongodb+srv:// URL WITH a database name. Without --mongo-uri the
                        URL is taken from $NEW_CLIENT_MONGO_URI, otherwise you are asked (hidden input).
                        A URL without a database name gets /<slug>_prod appended. It is stored only in
                        clients/<slug>/.env (0600) and never printed in full.
                        (Prefer the prompt or the variable: a command-line argument is visible in `ps`.)

Options:
  --catalog <file.xlsx> import a product catalog (catalog-import.js) after start-up
  --port-base N         first of 5 host ports: N proxy http, N+1 proxy https, N+2 api, N+3 admin, N+4 site
                        (default: derived from the slug, 20000-23990)
  --standard-ports      publish the proxy on 80/443 (needed for automatic HTTPS on a real domain)
  --behind-proxy        TLS is terminated by another proxy in front; this stack serves plain HTTP
  --admin-email <email> first admin (default admin@<domain>)
  --brand-short <name>  short name used in notifications (default: first word of the client name)
  --brand-email <email> --brand-phone <phone> --brand-address <text>
  --resume              finish a setup that failed half-way (clients/<slug> must exist)

There is no demo-data mode here: the backend's demo guard only allows a local database whose name contains
"demo", which an external MongoDB URL cannot satisfy. Run the demo locally instead:
  cd backend && npm run demo:mongo && npm run demo:reset && npm start
EOF
}

[ $# -ge 3 ] || { usage; exit 1; }
case "$1" in -h|--help) usage; exit 0 ;; esac

SLUG="$1"; CLIENT_NAME="$2"; DOMAIN="$3"; shift 3
MONGO_URI_ARG=""; CATALOG=""; PORT_BASE=""; STANDARD_PORTS=0; BEHIND_PROXY=0; RESUME=0
ADMIN_EMAIL_ARG=""; BRAND_SHORT=""; BRAND_EMAIL_ARG=""; BRAND_PHONE_ARG=""; BRAND_ADDRESS_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --empty) ;; # accepted for compatibility: an empty database is the only mode
    --demo-data) die "--demo-data is not available: the demo guard needs a local database named *demo*, which an external MongoDB URL cannot satisfy. Run the demo locally: cd backend && npm run demo:reset" ;;
    --mongo-uri) [ $# -ge 2 ] || die "--mongo-uri needs a value"; MONGO_URI_ARG="$2"; shift ;;
    --catalog) [ $# -ge 2 ] || die "--catalog needs a file"; CATALOG="$2"; shift ;;
    --port-base) [ $# -ge 2 ] || die "--port-base needs a number"; PORT_BASE="$2"; shift ;;
    --standard-ports) STANDARD_PORTS=1 ;;
    --behind-proxy) BEHIND_PROXY=1 ;;
    --admin-email) [ $# -ge 2 ] || die "--admin-email needs a value"; ADMIN_EMAIL_ARG="$2"; shift ;;
    --brand-short) [ $# -ge 2 ] || die "--brand-short needs a value"; BRAND_SHORT="$2"; shift ;;
    --brand-email) [ $# -ge 2 ] || die "--brand-email needs a value"; BRAND_EMAIL_ARG="$2"; shift ;;
    --brand-phone) [ $# -ge 2 ] || die "--brand-phone needs a value"; BRAND_PHONE_ARG="$2"; shift ;;
    --brand-address) [ $# -ge 2 ] || die "--brand-address needs a value"; BRAND_ADDRESS_ARG="$2"; shift ;;
    --resume) RESUME=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac
  shift
done

# ---------------------------------------------------------------- validation
validate_slug "$SLUG"
safe_text() { # <label> <value> <maxlen>
  [ -n "$2" ] || die "$1 must not be empty"
  [ "${#2}" -le "$3" ] || die "$1 is too long (max $3 characters)"
  case "$2" in
    *'"'*|*'\'*|*'$'*|*'`'*) die "$1 must not contain double quotes, backslashes, \$ or backticks" ;;
  esac
  if printf '%s' "$2" | LC_ALL=C grep -q '[[:cntrl:]]'; then die "$1 must not contain control characters"; fi
  return 0
}
safe_text "Client name" "$CLIENT_NAME" 80
DOMAIN="$(printf '%s' "$DOMAIN" | tr 'A-Z' 'a-z')"
printf '%s' "$DOMAIN" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$' || die "Invalid domain '$DOMAIN'"
[ "${#DOMAIN}" -le 100 ] || die "Domain is too long"

IS_LOCAL=0
case "$DOMAIN" in localhost|*.localhost) IS_LOCAL=1 ;; esac
if [ "$IS_LOCAL" = 0 ] && [ "$STANDARD_PORTS" = 0 ] && [ "$BEHIND_PROXY" = 0 ]; then
  die "'$DOMAIN' is a real domain: automatic HTTPS needs ports 80/443, so pass --standard-ports (this stack owns them) or --behind-proxy (another proxy terminates TLS and forwards plain HTTP to --port-base)."
fi
[ "$STANDARD_PORTS" = 0 ] || [ "$BEHIND_PROXY" = 0 ] || die "--standard-ports and --behind-proxy cannot be combined"

if [ -n "$CATALOG" ]; then
  [ -f "$CATALOG" ] && [ -r "$CATALOG" ] || die "Catalog file not found or unreadable: $CATALOG"
  CATALOG="$(cd "$(dirname "$CATALOG")" && pwd)/$(basename "$CATALOG")"
fi
if [ -n "$PORT_BASE" ]; then
  printf '%s' "$PORT_BASE" | grep -Eq '^[0-9]{4,5}$' || die "--port-base must be a number between 1024 and 65530"
  [ "$PORT_BASE" -ge 1024 ] && [ "$PORT_BASE" -le 65530 ] || die "--port-base must be between 1024 and 65530"
fi
for pair in "Admin email:$ADMIN_EMAIL_ARG" "Brand short name:$BRAND_SHORT" "Brand email:$BRAND_EMAIL_ARG" "Brand phone:$BRAND_PHONE_ARG" "Brand address:$BRAND_ADDRESS_ARG"; do
  value="${pair#*:}"
  [ -z "$value" ] || safe_text "${pair%%:*}" "$value" 200
done
if [ -n "$ADMIN_EMAIL_ARG" ]; then
  printf '%s' "$ADMIN_EMAIL_ARG" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' || die "Invalid --admin-email"
fi

CDIR="$(client_dir "$SLUG")"
ENVF="$(env_file "$SLUG")"
if [ -e "$CDIR" ]; then
  if [ "$RESUME" = 1 ] && [ -f "$ENVF" ]; then
    info "Resuming setup of existing client '$SLUG'"
  else
    die "clients/$SLUG already exists. Use ./update-client.sh $SLUG to redeploy, or --resume to finish a failed setup."
  fi
elif [ "$RESUME" = 1 ]; then
  die "--resume: clients/$SLUG does not exist"
fi

docker_ready
need_cmd openssl
need_cmd curl

if [ "$RESUME" = 0 ] && [ -n "$(project_containers "$SLUG")$(project_volumes "$SLUG")" ]; then
  die "Docker resources for project $(project_name "$SLUG") already exist without a config folder. Remove them with ./stop-client.sh or pick another slug."
fi

# ---------------------------------------------------------------- MongoDB URL
MONGO_URI=""
if [ "$RESUME" = 0 ]; then
  MONGO_URI="${MONGO_URI_ARG:-${NEW_CLIENT_MONGO_URI:-}}"
  if [ -z "$MONGO_URI" ]; then
    printf 'MongoDB URL for %s (mongodb:// or mongodb+srv://, input is hidden): ' "$SLUG" >&2
    IFS= read -r -s MONGO_URI || true
    printf '\n' >&2
  fi
  [ -n "$MONGO_URI" ] || die "A MongoDB URL is required (--mongo-uri, \$NEW_CLIENT_MONGO_URI or the prompt)"
  case "$MONGO_URI" in mongodb://?*|mongodb+srv://?*) ;; *) die "The MongoDB URL must start with mongodb:// or mongodb+srv://" ;; esac
  case "$MONGO_URI" in *[[:space:]]*|*"'"*|*'"'*|*'`'*) die "The MongoDB URL must not contain spaces or quote characters (percent-encode special characters in the password)" ;; esac
  if printf '%s' "$MONGO_URI" | LC_ALL=C grep -q '[[:cntrl:]]'; then die "The MongoDB URL contains control characters"; fi
  HOSTPART="${MONGO_URI#*://}"; HOSTPART="${HOSTPART%%/*}"; HOSTPART="${HOSTPART%%\?*}"; HOSTPART="${HOSTPART##*@}"
  case ",$HOSTPART," in
    *,localhost,*|*,localhost:*|*,127.0.0.1,*|*,127.0.0.1:*|*,\[::1\]*)
      die "In a container 'localhost' is the container itself. For a MongoDB on this machine use host.docker.internal (see README, MongoDB URL)." ;;
  esac
  DB_NAME="$(mongo_db_of "$MONGO_URI")"
  if [ -z "$DB_NAME" ]; then
    DB_NAME="${SLUG}_prod"
    base="${MONGO_URI%%\?*}"; base="${base%/}"
    case "$MONGO_URI" in *\?*) MONGO_URI="$base/$DB_NAME?${MONGO_URI#*\?}" ;; *) MONGO_URI="$base/$DB_NAME" ;; esac
    info "The URL had no database name; using '$DB_NAME' (appended to the URL)."
  fi
  printf '%s' "$DB_NAME" | grep -Eq '^[A-Za-z0-9_-]{1,63}$' || die "Database name '$DB_NAME' must use only letters, digits, '_' and '-'"
  case "$HOSTPART" in
    host.docker.internal*)
      case "$MONGO_URI" in *directConnection=true*|*replicaSet=*) ;; *) warn "A MongoDB on this machine is usually reached with ?directConnection=true (replica set members advertise names the container cannot resolve)." ;; esac ;;
  esac
  info "MongoDB: $(mask_uri "$MONGO_URI")  (database: $DB_NAME)"
fi

# ---------------------------------------------------------------- generate config
if [ "$RESUME" = 0 ]; then
  # ports
  PORT_BASE_ARG="$PORT_BASE"
  if [ -z "$PORT_BASE" ]; then
    sum="$(printf '%s' "$SLUG" | cksum | cut -d' ' -f1)"
    PORT_BASE=$((20000 + (sum % 400) * 10))
  fi
  used_by_clients() { # <port>
    local f
    for f in "$CLIENTS_DIR"/*/.env; do
      [ -f "$f" ] || continue
      grep -Eq "^(PROXY_HTTP_PORT|PROXY_HTTPS_PORT|BACKEND_PORT|ADMIN_PORT|SITE_PORT)=\"?$1\"?$" "$f" && return 0
    done
    return 1
  }
  ports_free() { # <base>
    local p
    for p in $(($1 + 0)) $(($1 + 1)) $(($1 + 2)) $(($1 + 3)) $(($1 + 4)); do
      if port_in_use "$p" || used_by_clients "$p"; then return 1; fi
    done
    return 0
  }
  if ! ports_free "$PORT_BASE"; then
    [ -z "$PORT_BASE_ARG" ] || die "Ports $PORT_BASE-$((PORT_BASE + 4)) are not all free (in use on this machine or by another client)"
    orig="$PORT_BASE"
    tries=0
    while ! ports_free "$PORT_BASE"; do
      PORT_BASE=$((PORT_BASE + 10)); tries=$((tries + 1))
      [ "$tries" -lt 50 ] && [ "$PORT_BASE" -le 65500 ] || die "No free block of 5 ports found near $orig; pass --port-base"
    done
    warn "Ports at $orig were busy; using --port-base $PORT_BASE"
  fi
  PROXY_HTTP_PORT="$PORT_BASE"; PROXY_HTTPS_PORT=$((PORT_BASE + 1))
  BACKEND_PORT=$((PORT_BASE + 2)); ADMIN_PORT=$((PORT_BASE + 3)); SITE_PORT=$((PORT_BASE + 4))
  PROXY_BIND="127.0.0.1"; TLS_MODE="local"
  if [ "$IS_LOCAL" = 1 ]; then TLS_MODE="local"; elif [ "$BEHIND_PROXY" = 1 ]; then TLS_MODE="proxy"; else TLS_MODE="auto"; fi
  if [ "$STANDARD_PORTS" = 1 ]; then
    PROXY_HTTP_PORT=80; PROXY_HTTPS_PORT=443
    for p in 80 443; do port_in_use "$p" && die "Port $p is already in use on this machine; --standard-ports needs it free"; done
    [ "$TLS_MODE" = "auto" ] && PROXY_BIND="0.0.0.0"
  fi

  # hostnames and public URLs
  API_HOST="api.$DOMAIN"; ADMIN_HOST="admin.$DOMAIN"; SITE_HOST="$DOMAIN"
  case "$TLS_MODE" in
    local)
      SCHEME="http"; SUFFIX=":$PROXY_HTTP_PORT"; [ "$PROXY_HTTP_PORT" = 80 ] && SUFFIX=""
      PREFIX="http://" ;;
    proxy) SCHEME="https"; SUFFIX=""; PREFIX="http://" ;;
    *) SCHEME="https"; SUFFIX=""; PREFIX="" ;;
  esac
  PUBLIC_API_URL="$SCHEME://$API_HOST$SUFFIX"
  PUBLIC_ADMIN_URL="$SCHEME://$ADMIN_HOST$SUFFIX"
  PUBLIC_SITE_URL="$SCHEME://$SITE_HOST$SUFFIX"

  # identity
  ADMIN_EMAIL="${ADMIN_EMAIL_ARG:-admin@$DOMAIN}"
  [ -n "$BRAND_SHORT" ] || BRAND_SHORT="${CLIENT_NAME%% *}"
  B_EMAIL="${BRAND_EMAIL_ARG:-hello@$DOMAIN}"
  B_PHONE="${BRAND_PHONE_ARG:-+91 00000 00000}"
  B_ADDRESS="${BRAND_ADDRESS_ARG:-100 Sample Street, Sample City}"

  # secrets (fresh per client; never printed)
  JWT_SECRET="$(openssl rand -hex 32)"
  JWT_REFRESH_SECRET="$(openssl rand -hex 32)"
  [ "${#JWT_SECRET}" -ge 48 ] || die "Could not generate a strong JWT secret (is openssl working?)"

  mkdir -p "$CLIENTS_DIR"
  ( umask 077
    mkdir -p "$CDIR"
    cat >"$ENVF" <<EOF
# Generated by new-client.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ). Contains secrets (MongoDB URL, JWT secrets): keep it out of git (it is gitignored).
# Edit values, then run ./update-client.sh $SLUG to apply them. See clients/example/.env.example for every variable.
CLIENT_SLUG="$SLUG"
CLIENT_NAME="$CLIENT_NAME"
DOMAIN="$DOMAIN"
TLS_MODE="$TLS_MODE"

# MongoDB: yours, not managed by this stack. Single-quoted on purpose (docker compose must not interpolate \$ in it).
MONGODB_URI='$MONGO_URI'
MONGO_DB_NAME="$DB_NAME"
MONGO_TOOLS_IMAGE="mongo:7"

API_HOST="$API_HOST"
ADMIN_HOST="$ADMIN_HOST"
SITE_HOST="$SITE_HOST"
API_ADDR="$PREFIX$API_HOST"
ADMIN_ADDR="$PREFIX$ADMIN_HOST"
SITE_ADDR="$PREFIX$SITE_HOST"
PUBLIC_API_URL="$PUBLIC_API_URL"
PUBLIC_ADMIN_URL="$PUBLIC_ADMIN_URL"
PUBLIC_SITE_URL="$PUBLIC_SITE_URL"

PORT_BASE="$PORT_BASE"
PROXY_BIND="$PROXY_BIND"
PROXY_HTTP_PORT="$PROXY_HTTP_PORT"
PROXY_HTTPS_PORT="$PROXY_HTTPS_PORT"
BACKEND_PORT="$BACKEND_PORT"
ADMIN_PORT="$ADMIN_PORT"
SITE_PORT="$SITE_PORT"

NODE_ENV="production"
JWT_SECRET="$JWT_SECRET"
JWT_REFRESH_SECRET="$JWT_REFRESH_SECRET"
JWT_ACCESS_EXPIRY="2h"
JWT_REFRESH_EXPIRY="7d"
TRUST_PROXY_HOPS="1"
CORS_ORIGIN="$PUBLIC_ADMIN_URL,$PUBLIC_SITE_URL"

ADMIN_EMAIL="$ADMIN_EMAIL"
ADMIN_EMAILS="$ADMIN_EMAIL"

BRAND_NAME="$CLIENT_NAME"
BRAND_SHORT_NAME="$BRAND_SHORT"
BRAND_LEGAL_NAME="$CLIENT_NAME"
BRAND_EMAIL="$B_EMAIL"
BRAND_PHONE="$B_PHONE"
BRAND_ADDRESS="$B_ADDRESS"
BRAND_WEBSITE="$PUBLIC_SITE_URL"

# Optional SMTP for admin sign-in emails (magic links).
SMTP_HOST=""
SMTP_PORT=""
SMTP_USER=""
SMTP_PASS=""
EMAIL_FROM=""
EOF
    cat >"$CDIR/brand.json" <<EOF
{
  "name": "$CLIENT_NAME",
  "shortName": "$BRAND_SHORT",
  "legalName": "$CLIENT_NAME",
  "email": "$B_EMAIL",
  "phone": "$B_PHONE",
  "address": "$B_ADDRESS",
  "website": "$PUBLIC_SITE_URL"
}
EOF
  )
  chmod 600 "$ENVF" "$CDIR/brand.json"
  info "Created $ENVF (secrets and MongoDB URL stored; mode 0600)"
fi
MONGO_URI=""

# ---------------------------------------------------------------- build + start
LOG="$CDIR/setup.log"
on_error() {
  warn "Setup of '$SLUG' did not finish. Config kept in clients/$SLUG (log: clients/$SLUG/setup.log)."
  if [ -n "$(project_containers "$SLUG" 2>/dev/null)" ]; then
    warn "Last API log lines (credentials masked):"
    dc "$SLUG" logs --no-color --tail 15 backend 2>&1 | sed -E 's#(mongodb(\+srv)?://)[^/@ ]*@#\1***:***@#g' >&2 || true
  fi
  warn "Fix the problem, then run:  ./new-client.sh $SLUG \"$CLIENT_NAME\" $DOMAIN --resume"
  warn "or discard it:              ./stop-client.sh $SLUG --destroy-data --remove-config   (your database is never touched)"
}
trap on_error ERR

TLS_MODE="$(cenv "$SLUG" TLS_MODE)"
PUBLIC_API_URL="$(cenv "$SLUG" PUBLIC_API_URL)"
PUBLIC_ADMIN_URL="$(cenv "$SLUG" PUBLIC_ADMIN_URL)"
PUBLIC_SITE_URL="$(cenv "$SLUG" PUBLIC_SITE_URL)"
ADMIN_EMAIL="$(cenv "$SLUG" ADMIN_EMAIL)"
DB_NAME="$(cenv "$SLUG" MONGO_DB_NAME)"
PROXY_HTTP_PORT="$(cenv "$SLUG" PROXY_HTTP_PORT)"
BACKEND_PORT="$(cenv "$SLUG" BACKEND_PORT)"
ADMIN_PORT="$(cenv "$SLUG" ADMIN_PORT)"
SITE_PORT="$(cenv "$SLUG" SITE_PORT)"
API_HOST="$(cenv "$SLUG" API_HOST)"
MASKED_URI="$(mask_uri "$(cenv "$SLUG" MONGODB_URI)")"

info "Building images (several minutes the first time; log: clients/$SLUG/setup.log)"
: >"$LOG"
for svc in backend admin site; do
  info "  building $svc ..."
  if ! dc "$SLUG" build "$svc" >>"$LOG" 2>&1; then
    tail -n 25 "$LOG" >&2
    die "Build of '$svc' failed"
  fi
done

info "Starting containers"
dc "$SLUG" up -d >>"$LOG" 2>&1 || { tail -n 25 "$LOG" >&2; die "docker compose up failed"; }
assert_project_owned "$SLUG"

info "Waiting for services to become healthy"
wait_healthy "$SLUG" backend 240
wait_healthy "$SLUG" admin 240
wait_healthy "$SLUG" site 240
wait_http "http://127.0.0.1:$BACKEND_PORT/health" "" 60 || die "API did not answer on 127.0.0.1:$BACKEND_PORT"
if [ "$TLS_MODE" != "auto" ]; then
  wait_http "http://127.0.0.1:$PROXY_HTTP_PORT/" "$API_HOST" 60 || warn "The proxy did not answer yet on port $PROXY_HTTP_PORT"
fi

# ---------------------------------------------------------------- bootstrap data
info "Creating the admin account $ADMIN_EMAIL"
OUT="$(dc "$SLUG" exec -T backend node scripts/create-admin.js --email "$ADMIN_EMAIL" --name "$(cenv "$SLUG" CLIENT_NAME) Admin" --link --link-minutes 60)" \
  || die "Could not create the admin account (is the database reachable and writable?)"
SIGN_IN_LINK="$(printf '%s\n' "$OUT" | sed -n 's/^SIGN_IN_LINK: //p' | head -n 1)"
printf '%s\n' "$OUT" | grep -v '^SIGN_IN_LINK' >>"$LOG" || true

if [ -n "$CATALOG" ]; then
  CAT_NAME="$(basename "$CATALOG")"
  if [ ! -f "$DEPLOY_DIR/../backend/scripts/catalog-import.js" ]; then
    warn "backend/scripts/catalog-import.js does not exist in this checkout; skipping --catalog"
  else
    info "Importing catalog $CAT_NAME (dry run first)"
    run_import() { # extra flags...
      dc "$SLUG" run --rm -T --no-deps -v "$CATALOG:/import/$CAT_NAME:ro" backend \
        node scripts/catalog-import.js "/import/$CAT_NAME" --actor "$ADMIN_EMAIL" "$@"
    }
    if run_import --dry-run --create-missing >>"$LOG" 2>&1; then
      run_import --create-missing 2>&1 | tee -a "$LOG" | tail -n 15 || warn "The catalog import reported errors (see clients/$SLUG/setup.log)"
    else
      tail -n 25 "$LOG" >&2
      warn "Catalog dry run failed; nothing was imported (details above and in clients/$SLUG/setup.log). The client itself is up; fix the file and import it later (see README, 'Importing a catalog')."
    fi
  fi
fi

# ---------------------------------------------------------------- credentials file + summary
CRED="$CDIR/ADMIN_CREDENTIALS.txt"
( umask 077
  {
    echo "Client:       $(cenv "$SLUG" CLIENT_NAME) ($SLUG)"
    echo "Admin panel:  $PUBLIC_ADMIN_URL"
    echo "Admin email:  $ADMIN_EMAIL"
    echo "Password:     none. The API refuses password sign-in for admins (DEMO_MODE is off)."
    echo "Sign in:      ./admin-login.sh $SLUG   (prints a one-time link; valid 30 minutes; no SMTP needed)"
    echo "              or set SMTP_* in .env and use the emailed magic link."
    echo "Database:     $MASKED_URI  (yours; this stack never drops it)"
  } >"$CRED"
)
chmod 600 "$CRED"
trap - ERR

echo
echo "=============================================================="
echo " $(cenv "$SLUG" CLIENT_NAME) is up  (project $(project_name "$SLUG"))"
echo "=============================================================="
echo " Site:         $PUBLIC_SITE_URL"
echo " Admin panel:  $PUBLIC_ADMIN_URL"
echo " API:          $PUBLIC_API_URL/api/v1   (health: $PUBLIC_API_URL/health)"
echo " Direct (loopback only): api http://127.0.0.1:$BACKEND_PORT  admin http://127.0.0.1:$ADMIN_PORT  site http://127.0.0.1:$SITE_PORT"
echo " Database:     $MASKED_URI  (database $DB_NAME)"
echo
echo " One-time admin sign-in link (shown once, valid 60 minutes, single use):"
echo "   $SIGN_IN_LINK"
echo " Need another later? ./admin-login.sh $SLUG"
echo " Details saved (0600): $CRED"
echo
if [ "$TLS_MODE" = "local" ]; then
  echo " *.localhost names resolve to 127.0.0.1 in Chrome, Firefox and curl. If your browser does not"
  echo " resolve them, add to /etc/hosts:  127.0.0.1 $(cenv "$SLUG" SITE_HOST) $(cenv "$SLUG" ADMIN_HOST) $API_HOST"
elif [ "$TLS_MODE" = "auto" ]; then
  echo " Point DNS A records for $(cenv "$SLUG" SITE_HOST), $(cenv "$SLUG" ADMIN_HOST) and $API_HOST at this server;"
  echo " certificates are issued automatically on first request (ports 80/443 must be reachable)."
else
  echo " Forward $(cenv "$SLUG" SITE_HOST), $(cenv "$SLUG" ADMIN_HOST), $API_HOST (Host header preserved) to http://127.0.0.1:$PROXY_HTTP_PORT."
fi
echo " Next: ./backup-client.sh $SLUG | ./update-client.sh $SLUG | ./export-client.sh $SLUG | ./stop-client.sh $SLUG"
