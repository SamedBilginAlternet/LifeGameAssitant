# Supabase — schema, functions, cron

This directory is what the Supabase GitHub integration watches:
migrations under `migrations/` deploy to the production project on
every merge to `main`, and Edge Functions under `functions/` deploy
via the workflow in `.github/workflows/` (or `supabase functions
deploy` from a local CLI).

## Migrations

Numbered, applied in order. Idempotent — re-running is safe.

| File | What it adds |
|------|--------------|
| `0001_init.sql` | `profiles` table + RLS + signup trigger |
| `0002_logs.sql` | Phase 1 tables (`daily_logs`, `fitness_data`, `learning_logs`, `entries`, `integration_runs`, github events) |
| `0003_cron_daily_summary.sql` | `pg_cron` schedule that pings `daily-summary` hourly at `:50` |
| `0004_integrations.sql` | `integrations` table for GitHub tokens |
| `0005_cron_github_poll.sql` | `pg_cron` schedule for `github-poll` (every 30 min) |
| `0006_richer_logs.sql` | `workouts`, `workout_sets`, `meals`, `movies_watched`, `motorcycle_rides` |
| `0007_music_and_photos.sql` | `music_listens`, `media_assets`, `covers/` + `voice/` Storage buckets, Spotify columns on `integrations` |
| `0008_cron_spotify_poll.sql` | `pg_cron` schedule for `spotify-poll` |
| `0009_voice.sql` | `voice_notes` table |
| `0010_weekly_summaries.sql` | `weekly_summaries` table |
| `0011_cron_weekly_summary.sql` | `pg_cron` schedule for `weekly-summary` Sundays at `:30` |
| `0012_seed_demo_user.sql` | **No-op.** Originally seeded `admin@demo.local`; raw-SQL inserts into `auth.users` couldn't satisfy GoTrue's user query. Seed demo users via the dashboard's Authentication → Users → Add user flow. |
| `0013_fix_demo_user.sql` | **No-op.** Failed second attempt at the same thing. |

### Prerequisites

Before the cron migrations (`0003`, `0005`, `0008`, `0011`) succeed:

1. Enable extensions in dashboard → Database → Extensions:
   - `pg_cron`
   - `pg_net`
2. Set custom Postgres config in dashboard → Database → Custom Postgres Config:
   - `app.functions_url` — e.g. `https://<project>.functions.supabase.co`
   - `app.cron_secret`   — long random string (also used as the `CRON_SECRET` Edge Function secret)

If you ran the cron migrations before either was set, just paste
those four files into the SQL Editor again — the migrations are
idempotent.

## Edge Functions

| Function | Trigger | What it does |
|----------|---------|--------------|
| `daily-summary` | `pg_cron` hourly `:50` (per-user TZ math) | Aggregates the day, calls Groq, writes to `entries` |
| `github-poll` | `pg_cron` every 30 min | Polls GitHub events for connected users → `github_events` |
| `spotify-poll` | `pg_cron` every 30 min | Refreshes the user's Spotify token, fetches recent plays → `music_listens` |
| `spotify-token-exchange` | App POST (auth-code exchange) | Completes the PKCE flow, persists refresh token |
| `voice-transcribe` | App POST after audio upload | Whisper → Llama → fills `transcript_de`, `transcript_en`, `corrections` |
| `weekly-summary` | `pg_cron` hourly `:30` on Sundays | Synthesises the week, writes to `weekly_summaries` |

### Required Edge Function secrets

Dashboard → Settings → Edge Functions → Secrets:

| Secret | Used by | How to get it |
|--------|---------|---------------|
| `GROQ_API_KEY` | `daily-summary`, `weekly-summary`, `voice-transcribe` | console.groq.com (free) |
| `CRON_SECRET` | All cron-invoked functions | Same string you put in `app.cron_secret` |
| `SPOTIFY_CLIENT_ID` | `spotify-poll`, `spotify-token-exchange` | developer.spotify.com → Dashboard → your app |

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` are
pre-populated by Supabase — don't override them.
