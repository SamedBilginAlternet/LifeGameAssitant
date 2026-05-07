# Architecture

## The three planes

```
┌───────────────────────────┐    ┌────────────────────────────┐    ┌───────────────────────────┐
│        CAPTURE            │    │          STORAGE           │    │        SYNTHESIS          │
│  (Flutter app + sources)  │ →  │  (Supabase: Postgres+Auth) │ →  │ (Edge Fn + Groq + Whisper)│
│                           │    │                            │    │                           │
│  • Manual quick-add       │    │  • daily_logs              │    │  • Nightly cron 23:50     │
│  • GitHub poller          │    │  • workouts                │    │  • Aggregates day's rows  │
│  • Health Connect / Kit   │    │  • movies_watched          │    │  • Picks cover photo      │
│  • Movie picker (TMDB)    │    │  • learning_logs           │    │  • Calls Groq → entry     │
│  • Voice memo (German)    │    │  • motorcycle_rides        │    │  • Whisper for voice DE   │
│  • Photo picker           │    │  • voice_notes             │    │                           │
│  • Mood slider            │    │  • media_assets            │    │                           │
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
| Movies             | Quick-add → TMDB search    | Pick result → `movies_watched` with `tmdb_id`    |
| Motorcycle rides   | Manual: distance + tag     | `motorcycle_rides` row                           |
| Voice notes (DE)   | Mic button                 | Local file → Storage → Whisper → translation row |
| Cover photo        | App pull at 23:45          | `photo_manager` → favorited or first-of-day → upload to Storage |
| Mood               | Evening notification       | Slider 1–10 → `daily_logs.mood_score`            |

## Cover photo selection

At 23:45 (5 minutes before the cron), the app runs a local job:

1. Read photos taken between 00:00 and 23:45 in the device's local timezone.
2. Prefer photos marked Favorite. If none, take the first photo of the day.
3. Compress to 1440px long edge, JPEG q80.
4. Upload to Supabase Storage bucket `covers/`. Insert `media_assets` row.
5. The `daily-summary` cron then knows to attach this asset to the entry.

If no photos exist, the entry uses a generated parchment texture as cover — never a blank header.

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
