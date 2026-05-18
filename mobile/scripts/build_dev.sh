#!/usr/bin/env bash
# Build dev APK — reads credentials from mobile/.env.
# Usage: ./scripts/build_dev.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if [[ ! -f .env ]]; then
  echo "ERROR: mobile/.env not found. Copy .env.example and fill in values." >&2
  exit 1
fi

# shellcheck disable=SC2046
export $(grep -v '^#' .env | xargs)

SUPABASE_URL="${SUPABASE_URL:?SUPABASE_URL not set in .env}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY not set in .env}"
SOCIETY_ID="${SOCIETY_ID:?SOCIETY_ID not set in .env}"
SENTRY_DSN="${SENTRY_DSN:-}"

flutter build apk --debug \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SOCIETY_ID="$SOCIETY_ID" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"

echo "Dev APK: build/app/outputs/flutter-apk/app-debug.apk"
