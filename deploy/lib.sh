#!/usr/bin/env bash
# Shared helpers for the per-client deploy scripts. Source it, do not run it.
# Works on macOS (bash 3.2) and Linux. Requires: docker (with the compose plugin), openssl, curl.
#
# Safety rules enforced here:
#  - every docker compose call goes through dc(), which pins the project to demomart-<slug>
#  - destructive/listing helpers check that every container, volume and network they act on
#    is labelled with that exact project AND carries the demomart-<slug> name prefix
#  - nothing here ever calls a global docker command (no system prune, no volume prune)

if [ -n "${DEMOMART_LIB_LOADED:-}" ]; then return 0; fi
DEMOMART_LIB_LOADED=1

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENTS_DIR="$DEPLOY_DIR/clients"
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
PROJECT_PREFIX="demomart-"

info() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but was not found in PATH"
}

docker_ready() {
  need_cmd docker
  docker info >/dev/null 2>&1 || die "The Docker daemon is not reachable. Start Docker and try again."
  docker compose version >/dev/null 2>&1 || die "The 'docker compose' plugin (v2) is required."
}

validate_slug() {
  case "${1:-}" in
    ''|*[!a-z0-9-]*) die "Invalid slug '${1:-}': use lowercase letters, digits and '-' only (2-30 characters)" ;;
  esac
  local len=${#1}
  if [ "$len" -lt 2 ] || [ "$len" -gt 30 ]; then
    die "Invalid slug '$1': must be 2-30 characters"
  fi
  case "$1" in -*|*-) die "Invalid slug '$1': must not start or end with '-'" ;; esac
  if [ "$1" = "example" ]; then die "'example' is reserved for the documented template"; fi
  return 0
}

project_name() { printf '%s%s' "$PROJECT_PREFIX" "$1"; }
client_dir() { printf '%s/%s' "$CLIENTS_DIR" "$1"; }
env_file() { printf '%s/%s/.env' "$CLIENTS_DIR" "$1"; }

require_client() {
  validate_slug "$1"
  [ -f "$(env_file "$1")" ] || die "No client '$1' (missing $(env_file "$1")). See ./list-clients.sh"
}

# env_get <file> <KEY>: value of KEY=... (last wins), surrounding double or single quotes removed.
env_get() {
  local value
  value="$(sed -n "s/^$2=//p" "$1" | tail -n 1)"
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
    \'*\') value="${value#\'}"; value="${value%\'}" ;;
  esac
  printf '%s' "$value"
}

# cenv <slug> <KEY>: read a value from the client's .env
cenv() { env_get "$(env_file "$1")" "$2"; }

# dc <slug> <compose args...>: docker compose pinned to this client's project and env file.
dc() {
  local slug="$1"
  shift
  docker compose -p "$(project_name "$slug")" --env-file "$(env_file "$slug")" -f "$COMPOSE_FILE" "$@"
}

# Names of everything labelled with this client's compose project.
project_containers() {
  docker ps -a --filter "label=com.docker.compose.project=$(project_name "$1")" --format '{{.Names}}'
}
project_volumes() {
  docker volume ls --filter "label=com.docker.compose.project=$(project_name "$1")" --format '{{.Name}}'
}
project_networks() {
  docker network ls --filter "label=com.docker.compose.project=$(project_name "$1")" --format '{{.Name}}'
}

# assert_project_owned <slug>: abort unless every labelled resource has the demomart-<slug> prefix.
assert_project_owned() {
  local slug="$1" prefix bad="" name
  prefix="$(project_name "$slug")"
  for name in $(project_containers "$slug") $(project_networks "$slug"); do
    case "$name" in "$prefix"-*|"$prefix"_*) ;; *) bad="$bad $name" ;; esac
  done
  for name in $(project_volumes "$slug"); do
    case "$name" in "$prefix"_*) ;; *) bad="$bad $name" ;; esac
  done
  [ -z "$bad" ] || die "Refusing to continue: resources without the '$prefix' prefix are labelled with this project:$bad"
}

# Safe timestamp for directory names.
stamp() { date +%Y%m%d-%H%M; }

# port_in_use <port>: true if something on this machine already listens there.
port_in_use() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
}

# container_health <slug> <service>: starting|healthy|unhealthy|none|missing
container_health() {
  local cid
  cid="$(dc "$1" ps -q "$2" 2>/dev/null | head -n 1)"
  [ -n "$cid" ] || { printf 'missing'; return 0; }
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || printf 'missing'
}

# wait_healthy <slug> <service> [timeout_seconds]
wait_healthy() {
  local slug="$1" service="$2" timeout="${3:-240}" waited=0 state
  while [ "$waited" -lt "$timeout" ]; do
    state="$(container_health "$slug" "$service")"
    case "$state" in
      healthy|running) return 0 ;;
      unhealthy|exited|dead) die "Service '$service' is $state. Check: docker compose -p $(project_name "$slug") logs $service" ;;
    esac
    sleep 3
    waited=$((waited + 3))
  done
  die "Timed out after ${timeout}s waiting for '$service' (state: $state)"
}

# wait_http <url> <host-header-or-empty> [timeout_seconds]: wait for any HTTP status < 500.
wait_http() {
  local url="$1" host="$2" timeout="${3:-120}" waited=0 code
  while [ "$waited" -lt "$timeout" ]; do
    if [ -n "$host" ]; then
      code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' -H "Host: $host" "$url" 2>/dev/null || true)"
    else
      code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" 2>/dev/null || true)"
    fi
    case "$code" in 2*|3*|4*) return 0 ;; esac
    sleep 3
    waited=$((waited + 3))
  done
  return 1
}

# read_line: read one line from stdin (works with a pipe as well as a terminal).
read_line() {
  local line=""
  IFS= read -r line || true
  printf '%s' "$line"
}

# sha256_of <file>
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

file_bytes() { wc -c <"$1" | tr -d ' '; }

# mask_uri <uri>: hide credentials (user:password@) so a MongoDB URL can be shown safely.
mask_uri() {
  printf '%s' "$1" | sed -E 's#^(mongodb(\+srv)?://)[^/@?]*@#\1***:***@#'
}

# mongo_db_of <uri>: database name in the URI path ('' when none).
mongo_db_of() {
  printf '%s' "$1" | sed -E 's#^mongodb(\+srv)?://[^/?]+/?([^/?]*).*$#\2#'
}

# dump_mongo <slug> <outfile>: gzip archive of the client's database.
# Runs mongodump in a one-shot, throwaway tools container (no server is started); the URL is read from the
# client's .env and handed over through the environment, never on a command line.
dump_mongo() {
  local slug="$1" out="$2" uri name image
  uri="$(cenv "$slug" MONGODB_URI)"
  [ -n "$uri" ] || die "MONGODB_URI is not set for $slug"
  image="$(cenv "$slug" MONGO_TOOLS_IMAGE)"; [ -n "$image" ] || image="mongo:7"
  name="$(project_name "$slug")-tools-$$"
  case "$name" in "$(project_name "$slug")"-tools-*) ;; *) die "internal error: unexpected tools container name $name" ;; esac
  MONGODB_URI="$uri" docker run --rm --name "$name" --label "demomart.client=$slug" \
    --add-host host.docker.internal:host-gateway -e MONGODB_URI "$image" \
    sh -c 'exec mongodump --uri="$MONGODB_URI" --archive --gzip --quiet' >"$out" \
    || die "mongodump failed (is the database reachable from Docker? see README, MongoDB URL)"
  gzip -t "$out" 2>/dev/null || die "The database dump is not a valid gzip file: $out"
  [ "$(file_bytes "$out")" -gt 100 ] || die "The database dump looks empty: $out"
}

# tar_uploads <slug> <outfile>: tar.gz of the uploads volume (public uploads + private media), read via the backend container.
tar_uploads() {
  local slug="$1" out="$2"
  dc "$slug" exec -T backend tar -C /data -czf - . >"$out" || die "Could not archive the uploads volume"
  gzip -t "$out" 2>/dev/null || die "The uploads archive is not a valid gzip file: $out"
}

# require_running <slug>: the API container must be up for exports and uploads archives.
require_running() {
  local state
  state="$(container_health "$1" backend)"
  case "$state" in healthy|running) ;; *) die "Service 'backend' of '$1' is not running (state: $state). Start it with ./update-client.sh $1" ;; esac
}
