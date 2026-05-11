#!/usr/bin/env bash
# Run the Flutter app locally with env injected by Infisical.
# Usage:
#   scripts/dev.sh                # defaults to -d chrome
#   scripts/dev.sh -d <device>    # passes through to flutter run
#
# Prerequisites:
#   - infisical CLI: https://infisical.com/docs/cli/overview
#   - You've run `infisical login` and `infisical init` once in this repo
#   - Flutter is on PATH

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_name="${INFISICAL_ENV:-dev}"

cd "$repo_root/app"

# infisical run --command "..." dispatches the string through sh -c, so
# the $VARS are expanded only after Infisical has populated them.
exec infisical run --env="$env_name" --command "flutter run \
  --dart-define=SUPABASE_URL=\$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=\$SUPABASE_ANON_KEY \
  --dart-define=SPOTIFY_CLIENT_ID=\${SPOTIFY_CLIENT_ID:-} \
  --dart-define=SPOTIFY_REDIRECT_URI=\${SPOTIFY_REDIRECT_URI:-memoirlog://spotify-callback} \
  $*"
