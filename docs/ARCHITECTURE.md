# Architecture

## The three planes

```
┌───────────────────────────┐    ┌────────────────────────────┐    ┌───────────────────────────┐
│        CAPTURE            │    │          STORAGE           │    │        SYNTHESIS          │
│  (Flutter app + sources)  │ →  │  (Supabase: Postgres+Auth) │ →  │ (Edge Fn + Groq + Whisper)│
│                           │    │                            │    │                           │
│  • Manual quick-add       │    │  • daily_logs              │    │  • Nightly cron 23:50     │
│  • GitHub poller          │    │  • workouts                │    │  • Aggregates day's rows  │
│  • Health Connect / Kit   │    │  • meals                   │    │  • Resolves cover photo   │
│  • Movie picker (TMDB)    │    │  • movies_watched          │    │  • Calls Groq → entry     │
│  • Spotify poller         │    │  • music_listens           │    │  • Whisper for voice DE   │
│  • Voice memo (German)    │    │  • learning_logs           │    │                           │
│  • Daily photo upload     │    │  • motorcycle_rides        │    │                           │
│  • Mood slider            │    │  • voice_notes             │    │                           │
│                           │    │  • media_assets            │    │                           │
└───────────────────────────┘    │  • entries  ◀──────────────┼────┤                           │
            ↑                    └────────────────────────────┘    └───────────────────────────┘
            │                                  │
            └────────── Realtime subscription on `entries` ──────────┐
                                                                     ↓
                                                              Flutter Diary UI
```

Three planes, three concerns. Capture writes raw rows. Storage holds them. Synthesis runs once a day to turn rows into narrative. The Flutter client never calls Groq directly — it subscribes to `entries` and renders whatever lands.

## Daily pipeline

```
00:00 ─────────── all day ─────────── 23:50 ─── 23:51 ─── 23:52 ─────── next morning
  │                  │                  │         │         │
  Day begins.    App writes events   pg_cron   Edge Fn   Whisper      Diary page
  Photos picked  to tables as they   fires     gathers   on voice     visible.
  for cover.     happen.             nightly.  rows →    notes.       Typewriter
                                               Groq.                  reveal.
```

The pipeline runs **once per day, server-side**. Consequences:

- API key never touches the device.
- Cost stays inside Groq's free tier (1 user × 1 call/day on a 70B model fits comfortably).
- App stays online-resilient — logs persist locally and flush to Supabase when reachable.

## Why Groq

| Property            | Why it matters here                                          |
|---------------------|--------------------------------------------------------------|
| Free tier           | Single-user product → zero ongoing cost.                     |
| OpenAI-compatible   | Plain `fetch` from a Deno Edge Function — no SDK needed.     |
| Inference speed     | The diary entry is generated in <1s. Enables on-demand re-runs. |
| Whisper hosted      | One vendor for both narration (Llama 3.3) and voice transcription. |

Endpoint: `https://api.groq.com/openai/v1/chat/completions`. Request shape is identical to OpenAI's chat completions API, so any OpenAI example translates directly.

## Data flow per source

| Source             | When                       | Mechanism                                        |
|--------------------|----------------------------|--------------------------------------------------|
| Manual quick-add   | On user tap                | Direct insert via `supabase_flutter`             |
| GitHub events      | Every 30 min               | Edge Fn polls `/users/:user/events`              |
| Steps / calories   | App foreground             | `health` package → batch upsert to `fitness_data`|
| Workouts           | After session (manual)     | Set/rep form → `workouts` row                    |
| **Meals**          | Quick-add per meal         | Title + macros (protein/cal/carbs) → `meals` row. Optional photo attached. |
| Movies             | Quick-add → TMDB search    | Pick result → `movies_watched` with `tmdb_id`    |
| **Music (Spotify)**| Every 30 min               | Edge Fn polls `/me/player/recently-played` → `music_listens`. Top track derived nightly. |
| Motorcycle rides   | Manual: distance + tag     | `motorcycle_rides` row                           |
| Voice notes (DE)   | Mic button                 | Local file → Storage → Whisper → translation row |
| **Daily photo**    | User tap "add photo"       | `image_picker` → compress → Storage → `media_assets(kind='cover')` |
| Mood               | Evening notification       | Slider 1–10 → `daily_logs.mood_score`            |

## Cover photo

The "Time Capsule" needs one image per day. Three resolution paths in priority order:

1. **User-uploaded (v1 default).** A `[+ PHOTO]` chip on the active day opens `image_picker`. Photo is compressed to 1440px long edge / JPEG q80, uploaded to private Storage bucket `covers/`, row written in `media_assets(kind='cover')`. The user can replace it any time before that day's entry is generated.
2. **Pixel-icon fallback.** If no photo by cron time, the daily-summary function picks the most representative icon from the curated 16×16 pixel set based on the day's dominant domain (top_skill). The entry still has a "cover" — just a glyph instead of a photo.
3. **Auto-pick (v2).** Optional setting that uses `photo_manager` to read the device library at 23:45 and pre-fill a Favorite or first-of-day shot. User confirms before upload — never a silent capture.

Photos are rendered through a 1-bit dither shader on the diary page so they sit visually inside the CRT aesthetic instead of fighting it. The original is always kept; the dither is a render-time effect.

## Spotify integration

OAuth 2.0 with PKCE. Login flow once, refresh token stored in Supabase Vault.

```
Settings → Integrations → Connect Spotify
  → in-app browser opens accounts.spotify.com/authorize
  → redirect back to memoirlog://spotify-callback?code=...
  → Edge Fn `spotify-exchange` swaps code → tokens → Vault
```

A `spotify-poll` Edge Function runs every 30 minutes via `pg_cron`:

1. Refresh the access token if expired.
2. Hit `GET /me/player/recently-played?limit=50&after=<last_poll>`.
3. Upsert each play into `music_listens` (dedupe on `played_at`).
4. The nightly summary computes "top of day" by play count + total duration.

Scope requested: `user-read-recently-played` only. We do not control playback, do not read playlists, do not see followers.

YT Music has no official API. v2 plan: optional Last.fm scrobbler bridge — user enables Last.fm scrobbling from any source, we poll Last.fm's public `user.getRecentTracks` endpoint.

## Voice → German practice flow

```
mic tap → record .m4a (max 60s) → upload to private Storage bucket
        → Whisper transcribe (German)
        → Llama 3.3 translate to English + return corrections
        → write voice_notes row {original_de, english, corrections, audio_url}
```

The diary entry mentions the voice note inline ("…and on the couch he recorded a thought in German about *Distributed Systems*…") and the entry view exposes a play button + the corrected transcript. This is the project's German A2 practice loop.

## Auth model

- Single-user product. Each install = one Supabase `auth.users` row.
- Apple / Google sign-in via Supabase Auth.
- Every table has `user_id uuid` + RLS: `auth.uid() = user_id`. No exceptions.
- Edge Functions use the service role key only for cron-driven writes; user-facing reads/writes go through the user's JWT.

## Failure handling

| Failure                        | Behavior                                                   |
|--------------------------------|------------------------------------------------------------|
| Groq rate-limit / 5xx          | Insert `entries` row with `status='failed'`, retry next morning |
| Day has zero data              | Skip Groq, insert `status='empty'` placeholder ("a quiet day") |
| GitHub poll fails              | Log to `integration_runs`, retry next cycle                |
| Whisper fails                  | Keep audio, mark `voice_notes.status='pending'`, retry tomorrow |
| App offline                    | Hive write queue, flush on reconnect                       |

## Privacy posture

- No raw GPS coordinates. Motorcycle rides record distance + named route only.
- No automatic photo upload — only the one cover image, uploaded after a local pick.
- Groq receives **aggregated counts and tags** plus optional voice transcripts that the user explicitly recorded.
- Voice audio lives in a private Storage bucket with RLS; the user can purge it from Settings.
- All tables encrypted at rest (Supabase default). Backups retained 7 days.
