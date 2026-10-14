#!/usr/bin/env bash
# List configured clients and the state of their containers (only demomart-* resources are shown).
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

docker_ready
printf '%-18s %-16s %-9s %-34s %s\n' SLUG DATABASE STATE ADMIN_URL PORTS
found=0
for f in "$CLIENTS_DIR"/*/.env; do
  [ -f "$f" ] || continue
  slug="$(basename "$(dirname "$f")")"
  [ "$slug" = "example" ] && continue
  found=1
  total="$(docker ps -a --filter "label=com.docker.compose.project=$(project_name "$slug")" --format '{{.Names}}' | grep -c . || true)"
  running="$(docker ps --filter "label=com.docker.compose.project=$(project_name "$slug")" --format '{{.Names}}' | grep -c . || true)"
  if [ "$total" = 0 ]; then state="stopped"; elif [ "$running" -ge 4 ]; then state="up"; else state="partial($running/$total)"; fi
  printf '%-18s %-16s %-9s %-34s http:%s api:%s admin:%s site:%s\n' "$slug" "$(env_get "$f" MONGO_DB_NAME)" "$state" \
    "$(env_get "$f" PUBLIC_ADMIN_URL)" "$(env_get "$f" PROXY_HTTP_PORT)" "$(env_get "$f" BACKEND_PORT)" "$(env_get "$f" ADMIN_PORT)" "$(env_get "$f" SITE_PORT)"
done
[ "$found" = 1 ] || echo "(no clients yet; create one with ./new-client.sh)"

# Compose projects that have containers or volumes but no clients/<slug> folder.
orphans=""
for name in $(docker ps -a --format '{{.Names}}' | awk '/^demomart-/'); do
  proj="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null || true)"
  case "$proj" in "$PROJECT_PREFIX"*) ;; *) continue ;; esac
  slug="${proj#"$PROJECT_PREFIX"}"
  [ -f "$(env_file "$slug")" ] || orphans="$orphans $name"
done
[ -z "$orphans" ] || warn "demomart-* containers without a clients/<slug> config:$orphans"
