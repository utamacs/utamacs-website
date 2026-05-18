#!/usr/bin/env bash
# Build production release APK — all secrets injected via environment, never .env file.
# Usage: SUPABASE_URL=... SUPABASE_ANON_KEY=... SOCIETY_ID=... SENTRY_DSN=... ./scripts/build_prod.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

SUPABASE_URL="${SUPABASE_URL:?SUPABASE_URL env var required}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY env var required}"
SOCIETY_ID="${SOCIETY_ID:?SOCIETY_ID env var required}"
SENTRY_DSN="${SENTRY_DSN:?SENTRY_DSN env var required}"

flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SOCIETY_ID="$SOCIETY_ID" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"

echo "Release APK: build/app/outputs/flutter-apk/app-release.apk"
