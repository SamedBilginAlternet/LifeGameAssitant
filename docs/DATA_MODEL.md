# Data Model

All tables are owned by the user via `user_id uuid references auth.users`. Every table has an RLS policy: `auth.uid() = user_id`. The schema is intentionally narrow — no over-modeling for hypothetical features.

## Tables

### `profiles`
One row per user. Created via trigger on `auth.users` insert.

| Column         | Type        | Notes                                     |
|----------------|-------------|-------------------------------------------|
| `id`           | uuid PK     | = `auth.users.id`                         |
| `display_name` | text        |                                           |
| `timezone`     | text        | IANA, e.g. `Europe/Istanbul`.             |
| `summary_time` | time        | Default `23:50`.                          |
| `narrator_voice` | text      | `mentor` \| `historian` \| `coach`.       |
| `german_level` | text        | `A2` (default). Drives voice-note feedback. |
| `created_at`   | timestamptz | default `now()`                           |

### `daily_logs`
The day's "header." One per user per local date. Aggregation anchor.

| Column         | Type        | Notes                                     |
|----------------|-------------|-------------------------------------------|
| `id`           | uuid PK     |                                           |
| `user_id`      | uuid        |                                           |
| `local_date`   | date        | UNIQUE with `user_id`                     |
| `mood_score`   | int         | 1–10, nullable                            |
| `note`         | text        | optional free-text                        |
| `created_at`   | timestamptz |                                           |

### `entries`
The diary. The product's output.

| Column         | Type        | Notes                                     |
|----------------|-------------|-------------------------------------------|
| `id`           | uuid PK     |                                           |
| `user_id`      | uuid        |                                           |
| `local_date`   | date        | UNIQUE with `user_id`                     |
| `body`         | text        | The narrative paragraph (~100 words).     |
| `top_skill`    | text        | `logic` \| `vitality` \| `linguistics` \| `culture` \| `academic` |
| `cover_asset_id` | uuid      | references `media_assets(id)`             |
| `mood_tint`    | text        | hex shade applied to the page background  |
| `stats_json`   | jsonb       | snapshot of input sent to Groq            |
| `status`       | text        | `ok` \| `failed` \| `empty`               |
| `model`        | text        | e.g. `llama-3.3-70b-versatile`            |
| `generated_at` | timestamptz |                                           |

### `github_events`
Filled by the GitHub poller Edge Function.

| Column        | Type        | Notes                                     |
|---------------|-------------|-------------------------------------------|
| `id`          | uuid PK     |                                           |
| `user_id`     | uuid        |                                           |
| `local_date`  | date        |                                           |
| `event_type`  | text        | `push` \| `pr_opened` \| `pr_merged` \| `issue` |
| `repo`        | text        |                                           |
| `commits`     | int         |                                           |
| `payload`     | jsonb       |                                           |
| `occurred_at` | timestamptz |                                           |

### `fitness_data`
Latest-write-wins on metric per day.

| Column        | Type        | Notes                                     |
|---------------|-------------|-------------------------------------------|
| `id`          | uuid PK     |                                           |
| `user_id`     | uuid        |                                           |
| `local_date`  | date        |                                           |
| `metric`      | text        | `steps` \| `calories` \| `protein_g` \| `weight_kg` |
| `value`       | numeric     |                                           |
| `source`      | text        | `health_connect` \| `healthkit` \| `manual` |
| UNIQUE        | `(user_id, local_date, metric)`                       |

### `workouts`
One row per gym session.

| Column          | Type        | Notes                                   |
|-----------------|-------------|-----------------------------------------|
| `id`            | uuid PK     |                                         |
| `user_id`       | uuid        |                                         |
| `local_date`    | date        |                                         |
| `name`          | text        | "Push Day", "Legs", "Pull"              |
| `duration_min`  | int         |                                         |
| `total_volume_kg` | numeric   | sum(weight × reps)                      |
| `notes`         | text        |                                         |
| `started_at`    | timestamptz |                                         |

### `workout_sets`
Children of `workouts`.

| Column        | Type        | Notes                                     |
|---------------|-------------|-------------------------------------------|
| `id`          | uuid PK     |                                           |
| `workout_id`  | uuid        | FK                                        |
| `exercise`    | text        | "Bench Press"                             |
| `weight_kg`   | numeric     |                                           |
| `reps`        | int         |                                           |
| `rpe`         | int         | 1–10, nullable                            |
| `set_index`   | int         |                                           |

### `movies_watched`

| Column        | Type        | Notes                                     |
|---------------|-------------|-------------------------------------------|
| `id`          | uuid PK     |                                           |
| `user_id`     | uuid        |                                           |
| `local_date`  | date        |                                           |
| `tmdb_id`     | int         | from TMDB search                          |
| `title`       | text        |                                           |
| `release_year`| int         |                                           |
| `poster_path` | text        | TMDB-relative path                        |
| `rating`      | int         | 1–5 stars, nullable                       |
| `medium`      | text        | `cinema` \| `streaming` \| `tv`           |

### `learning_logs`

| Column        | Type        | Notes                                     |
|---------------|-------------|-------------------------------------------|
| `id`          | uuid PK     |                                           |
| `user_id`     | uuid        |                                           |
| `local_date`  | date        |                                           |
| `track`       | text        | `german` \| `masters` \| `algorithms` \| `book` |
| `minutes`     | int         |                                           |
| `topic`       | text        | "Distributed Systems", "Modalverben"      |

### `motorcycle_rides`

| Column         | Type        | Notes                                    |
|----------------|-------------|------------------------------------------|
| `id`           | uuid PK     |                                          |
| `user_id`      | uuid        |                                          |
| `local_date`   | date        |                                          |
| `distance_km`  | numeric     |                                          |
| `duration_min` | int         |                                          |
| `route_tag`    | text        | "Bosphorus", "Commute", "Anatolian Side" |
| `notes`        | text        |                                          |

### `voice_notes`

| Column          | Type        | Notes                                   |
|-----------------|-------------|-----------------------------------------|
| `id`            | uuid PK     |                                         |
| `user_id`       | uuid        |                                         |
| `local_date`    | date        |                                         |
| `audio_path`    | text        | Storage path in `voice/` bucket         |
| `language`      | text        | `de` \| `tr` \| `en`                    |
| `transcript`    | text        | original-language transcription         |
| `english`       | text        | translation                             |
| `corrections`   | jsonb       | `[{ original, suggested, reason }]` for German A2 feedback |
| `status`        | text        | `pending` \| `ok` \| `failed`           |
| `duration_sec`  | int         |                                         |

### `media_assets`
Cover photos and any other media attached to entries.

| Column         | Type        | Notes                                    |
|----------------|-------------|------------------------------------------|
| `id`           | uuid PK     |                                          |
| `user_id`      | uuid        |                                          |
| `local_date`   | date        |                                          |
| `kind`         | text        | `cover` \| `voice` \| `movie_poster`     |
| `storage_path` | text        | full path in Supabase Storage            |
| `width`        | int         |                                          |
| `height`       | int         |                                          |
| `dominant_hex` | text        | drives `entries.mood_tint` if no mood set |

### `integrations`
Third-party secrets (Vault-encrypted).

| Column         | Type      | Notes                                   |
|----------------|-----------|-----------------------------------------|
| `user_id`      | uuid PK   |                                         |
| `github_token` | text      | read-only PAT                           |
| `github_login` | text      |                                         |
| `tmdb_token`   | text      | optional, read-only                     |

### `integration_runs`
Audit log for the pollers + cron jobs.

| Column   | Type        | Notes                                     |
|----------|-------------|-------------------------------------------|
| `id`     | bigserial PK|                                           |
| `user_id`| uuid        |                                           |
| `kind`   | text        | `github_poll` \| `daily_summary` \| `voice_transcribe` |
| `status` | text        | `ok` \| `error`                           |
| `error`  | text        |                                           |
| `ran_at` | timestamptz |                                           |

## Indexes

```sql
create index on github_events    (user_id, local_date);
create index on fitness_data     (user_id, local_date);
create index on workouts         (user_id, local_date);
create index on workout_sets     (workout_id);
create index on movies_watched   (user_id, local_date);
create index on learning_logs    (user_id, local_date);
create index on motorcycle_rides (user_id, local_date);
create index on voice_notes      (user_id, local_date);
create index on media_assets     (user_id, local_date, kind);
create index on entries          (user_id, local_date desc);  -- the timeline scroll
```

## RLS template

```sql
alter table workouts enable row level security;
create policy "own rows only" on workouts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```
Same template for every table except `profiles` (uses `auth.uid() = id`).

## Storage buckets

| Bucket    | Privacy  | Contents                              |
|-----------|----------|---------------------------------------|
| `covers/` | private  | One cover image per day, ~300 KB.     |
| `voice/`  | private  | `.m4a` voice memos, ≤ 60s.            |

Bucket policies mirror the RLS rule via signed URLs. The Flutter client never embeds a service-role key.

## Cron jobs

```sql
-- 30-min GitHub poll
select cron.schedule(
  'github-poll', '*/30 * * * *',
  $$ select net.http_post(
       url := 'https://<project>.functions.supabase.co/github-poll',
       headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.cron_token'))
     ); $$
);

-- Nightly summary at 23:50 UTC. The function loops users in their own timezone
-- and only summarizes those whose local time has crossed `summary_time`.
select cron.schedule(
  'daily-summary', '50 23 * * *',
  $$ select net.http_post(
       url := 'https://<project>.functions.supabase.co/daily-summary',
       headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.cron_token'))
     ); $$
);
```

## Migration discipline

- Numbered files in `supabase/migrations/` (e.g. `0001_init.sql`).
- Never edit a shipped migration — always add a new one.
- Each migration is self-contained and idempotent where possible.
