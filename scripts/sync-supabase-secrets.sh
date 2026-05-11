#!/usr/bin/env bash
# Pull dev secrets from Infisical and push them to Supabase Edge
# Function Secrets via `supabase secrets set --env-file`.
#
# Only the secrets Edge Functions actually need are forwarded — see
# SERVER_KEYS below. The rest stay in Infisical for the Flutter client
# to consume via scripts/dev.sh.
#
# Usage:
#   scripts/sync-supabase-secrets.sh
#
# Prerequisites:
#   - infisical CLI authed, init'd in this repo
#   - supabase CLI authed, linked to the project (`supabase link`)

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_name="${INFISICAL_ENV:-dev}"

# Edge Function-side secrets ONLY. Public client values
# (SUPABASE_URL, SUPABASE_ANON_KEY) are NOT pushed — Supabase
# auto-populates those for every function via the runtime environment.
SERVER_KEYS=(
  GROQ_API_KEY
  CRON_SECRET
  SPOTIFY_CLIENT_ID
)

tmp_env="$(mktemp)"
trap 'rm -f "$tmp_env"' EXIT

echo "→ pulling secrets from Infisical (env=$env_name)..."
cd "$repo_root"

# infisical export emits KEY=value lines for the selected env.
all_secrets="$(infisical export --env="$env_name" --format=dotenv)"

# Filter to only the keys we want exposed to Edge Functions.
for key in "${SERVER_KEYS[@]}"; do
  line="$(echo "$all_secrets" | grep -E "^${key}=" || true)"
  if [ -z "$line" ]; then
    echo "  ⚠ skipping $key — not set in Infisical $env_name"
    continue
  fi
  echo "$line" >> "$tmp_env"
done

if [ ! -s "$tmp_env" ]; then
  echo "✗ no server-side secrets found in Infisical $env_name; nothing to push."
  exit 1
fi

echo "→ pushing to Supabase Edge Function Secrets..."
supabase secrets set --env-file "$tmp_env"

echo "✓ done."
