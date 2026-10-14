#!/usr/bin/env bash
# Print a one-time admin sign-in link for a client (no SMTP needed).
# Needed because, with DEMO_MODE=false, the API only lets admins in through an emailed magic link.
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[ $# -ge 1 ] || { echo "Usage: ./admin-login.sh <slug> [--minutes N] [--email admin@example.com]"; exit 1; }
SLUG="$1"; shift
MINUTES=30; EMAIL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --minutes) [ $# -ge 2 ] || die "--minutes needs a number"; MINUTES="$2"; shift ;;
    --email) [ $# -ge 2 ] || die "--email needs a value"; EMAIL="$2"; shift ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done
printf '%s' "$MINUTES" | grep -Eq '^[0-9]{1,4}$' || die "--minutes must be a number"
require_client "$SLUG"
docker_ready
assert_project_owned "$SLUG"
[ -n "$EMAIL" ] || EMAIL="$(cenv "$SLUG" ADMIN_EMAIL)"
OUT="$(dc "$SLUG" exec -T backend node scripts/create-admin.js --email "$EMAIL" --name "$(cenv "$SLUG" CLIENT_NAME) Admin" --link --link-minutes "$MINUTES")"
LINK="$(printf '%s\n' "$OUT" | sed -n 's/^SIGN_IN_LINK: //p' | head -n 1)"
[ -n "$LINK" ] || die "No link was issued"
echo "One-time sign-in link for $EMAIL (single use, valid $MINUTES minutes):"
echo "  $LINK"
